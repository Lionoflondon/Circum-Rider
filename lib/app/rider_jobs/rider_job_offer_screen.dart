// ignore_for_file: deprecated_member_use, prefer_const_constructors, curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../communication/rider_conversation_view.dart';
import '../home/bloc/home_bloc.dart';
import '../founder_access/founder_rider_access.dart';
import '../rider_design/rider_ui.dart';
import '../rider_truth/rider_truth.dart';
import '../support/view/support.dart';
import '../tracking/rider_live_tracking_controller.dart';
import 'rider_accept_controller.dart';
import 'rider_delivery_controller.dart';
import 'rider_dispatch_policy.dart';
import 'rider_offer_card.dart';
import 'rider_offer_stack.dart';

class RiderJobOfferScreen extends StatefulWidget {
  static const routeName = '/rider/jobs/offers';

  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;
  final RiderAcceptController? acceptController;
  final List<RiderJobOffer>? previewOffers;
  final VoidCallback? onScheduledAccepted;
  final ValueChanged<int>? onNavigateTab;

  const RiderJobOfferScreen({
    super.key,
    this.firestore,
    this.auth,
    this.acceptController,
    this.previewOffers,
    this.onScheduledAccepted,
    this.onNavigateTab,
  });

  @override
  State<RiderJobOfferScreen> createState() => _RiderJobOfferScreenState();
}

class _RiderJobOfferScreenState extends State<RiderJobOfferScreen> {
  late final FirebaseFirestore _firestore;
  late final FirebaseAuth _auth;
  late final RiderAcceptController _acceptController;
  int _activeIndex = 0;
  bool _accepting = false;
  bool _accepted = false;
  String? _statusMessage;
  RiderAcceptStatus? _acceptStatus;

  @override
  void initState() {
    super.initState();
    if (widget.previewOffers != null) return;
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
    _auth = widget.auth ?? FirebaseAuth.instance;
    _acceptController = widget.acceptController ??
        RiderAcceptController(
          store: CallableRiderJobTransactionStore(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final previewOffers = widget.previewOffers;
    if (previewOffers != null) {
      return _OfferExperience(
        offers: previewOffers,
        activeIndex: _activeIndex,
        accepting: _accepting,
        accepted: _accepted,
        riderRank: 'Sentinel',
        statusMessage: _statusMessage,
        acceptStatus: _acceptStatus,
        onBackToFeed: _resetTakenState,
        onIndexChanged: (index) {
          setState(() {
            _activeIndex = index;
            _statusMessage = null;
            _acceptStatus = null;
          });
        },
        onAccept: _acceptPreview,
      );
    }

    final user = _auth.currentUser;
    if (user == null) {
      return const _StateScaffold(
        title: 'Sign in required',
        message: 'Sign in to view rider offers.',
      );
    }

    context.watch<HomeBloc>().state;
    return FutureBuilder<bool>(
        future: FounderRiderAccess.enabled(),
        builder: (context, founderSnapshot) {
          final founder = founderSnapshot.data == true;
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('riders').doc(user.uid).snapshots(),
            builder: (context, riderSnapshot) {
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _firestore
                    .collection('riderProfiles')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, profileSnapshot) {
                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _firestore
                        .collection('riderPresence')
                        .doc(user.uid)
                        .snapshots(),
                    builder: (context, presenceSnapshot) {
                      final riderData = <String, dynamic>{
                        ...?profileSnapshot.data?.data(),
                        ...?riderSnapshot.data?.data()
                      };
                      final presence =
                          presenceSnapshot.data?.data() ?? const {};
                      final rider =
                          _riderProfile(user.uid, riderData, founder: founder);
                      final online = presence['isOnline'] == true &&
                          '${presence['availabilityStatus'] ?? ''}'
                                  .toLowerCase() !=
                              'offline';
                      final connectionLost =
                          '${presence['connectionStatus'] ?? ''}'
                                  .toLowerCase() ==
                              'lost';

                      if (!rider.canAcceptJobs)
                        return _JobsStateScaffold(
                            title: 'Account action required',
                            message: rider.blockedReason ??
                                'Your Rider account cannot receive jobs right now.');
                      if (!online)
                        return _JobsStateScaffold(
                            title: "You're offline",
                            message:
                                'Go online to receive eligible delivery offers.',
                            actionLabel: 'Go Online',
                            onAction: () => context
                                .read<HomeBloc>()
                                .add(SetRideStatus(status: RideStatus.online)));
                      if (connectionLost)
                        return const _JobsStateScaffold(
                          title: 'Reconnecting',
                          message:
                              'You are still online. We will show nearby offers once your live location reconnects.',
                          loading: true,
                        );

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _firestore
                            .collection('deliveryRequests')
                            .where('status', isEqualTo: 'requested')
                            .limit(20)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const _JobsStateScaffold(
                              title: 'Network error',
                              message:
                                  'We could not load offers. Please try again.',
                            );
                          }

                          if (!snapshot.hasData ||
                              (riderSnapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  profileSnapshot.connectionState ==
                                      ConnectionState.waiting)) {
                            return const _JobsStateScaffold(
                              title: 'Loading offers',
                              message: 'Checking nearby delivery requests.',
                              loading: true,
                            );
                          }

                          final offers = _filterOffers(
                            docs: snapshot.data!.docs,
                            rider: rider,
                            founder: founder,
                          );

                          if (_activeIndex >= offers.length &&
                              offers.isNotEmpty) {
                            scheduleMicrotask(() {
                              if (mounted)
                                setState(
                                    () => _activeIndex = offers.length - 1);
                            });
                          }

                          if (offers.isEmpty) {
                            return const _JobsStateScaffold(
                              title: 'No offers nearby',
                              message:
                                  'New delivery offers will appear here when available.',
                            );
                          }

                          final safeIndex =
                              _activeIndex.clamp(0, offers.length - 1);
                          return _OfferExperience(
                            offers: offers,
                            activeIndex: safeIndex,
                            accepting: _accepting,
                            accepted: _accepted,
                            riderRank: rider.riderRank ?? 'Sentinel',
                            statusMessage: _statusMessage,
                            acceptStatus: _acceptStatus,
                            onBackToFeed: _resetTakenState,
                            onIndexChanged: (index) {
                              setState(() {
                                _activeIndex = index;
                                _accepted = false;
                                _statusMessage = null;
                                _acceptStatus = null;
                              });
                            },
                            onAccept: (offer) => _accept(offer, rider),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        });
  }

  RiderProfileSnapshot _riderProfile(String uid, Map<String, dynamic> riderData,
      {bool founder = false}) {
    final canAccept = founder || RiderOnboardingPolicy.canAcceptJobs(riderData);
    final firstName = '${riderData['firstName'] ?? ''}'.trim();
    final lastName = '${riderData['lastName'] ?? ''}'.trim();
    final displayName =
        [firstName, lastName].where((part) => part.isNotEmpty).join(' ').trim();
    final vehicle = riderData['vehicle'] is Map
        ? '${riderData['vehicle']['type'] ?? riderData['vehicleType'] ?? ''}'
        : '${riderData['vehicleType'] ?? riderData['typeOfVehicle'] ?? ''}';
    final vehicles = _riderVehicles(riderData, vehicle);
    final trustPoints =
        _intValue(riderData['trustPoints'] ?? riderData['trustTotal']) ?? 0;
    final activeDeliveryId =
        '${riderData['activeDeliveryId'] ?? riderData['currentDeliveryId'] ?? ''}'
            .trim();
    final reservedScheduled = _stringList(riderData['reservedScheduledJobIds']);

    return RiderProfileSnapshot(
      riderId: uid,
      riderName: displayName.isEmpty ? null : displayName,
      riderVehicle: vehicle.trim().isEmpty ? null : vehicle.trim(),
      riderVehicles: vehicles,
      riderRank: RiderRankSnapshot.from(riderData)?.rank,
      trustPoints: trustPoints,
      canAcceptJobs: canAccept,
      blockedReason:
          canAccept ? null : RiderOnboardingPolicy.blockedReason(riderData),
      activeDeliveryId: activeDeliveryId.isEmpty ? null : activeDeliveryId,
      reservedScheduledJobIds: reservedScheduled,
    );
  }

  List<RiderJobOffer> _filterOffers({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required RiderProfileSnapshot rider,
    bool founder = false,
  }) {
    return docs
        .where((doc) => _isVisibleToRider(doc.data(), rider, founder: founder))
        .map((doc) =>
            RiderJobOffer.fromFirestore(docId: doc.id, data: doc.data()))
        .toList();
  }

  bool _isVisibleToRider(Map<String, dynamic> data, RiderProfileSnapshot rider,
      {bool founder = false}) {
    return RiderDispatchPolicy.visibleToRider(
      job: data,
      rider: RiderDispatchContext(
        riderId: rider.riderId,
        vehicles: rider.riderVehicles.isEmpty
            ? [if ((rider.riderVehicle ?? '').isNotEmpty) rider.riderVehicle!]
            : rider.riderVehicles,
        activeDeliveryId: rider.activeDeliveryId,
        reservedScheduledJobIds: rider.reservedScheduledJobIds,
        trustPoints: rider.trustPoints,
        founderOverride: founder,
      ),
    ).eligible;
  }

  List<String> _stringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => '$item'.trim())
          .where((v) => v.isNotEmpty)
          .toList();
    }
    return const [];
  }

  List<String> _riderVehicles(Map<String, dynamic> riderData, String vehicle) {
    final vehicles = <String>[];
    void add(dynamic value) {
      final text = '$value'.trim();
      if (value != null && text.isNotEmpty && text != 'null') {
        vehicles.add(text);
      }
    }

    add(vehicle);
    final rawVehicles = riderData['vehicles'];
    if (rawVehicles is Iterable) {
      for (final item in rawVehicles) {
        if (item is Map) {
          add(item['type'] ?? item['vehicleType'] ?? item['class']);
        } else {
          add(item);
        }
      }
    }
    return vehicles.toSet().toList();
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('$value');
  }

  Future<void> _accept(
    RiderJobOffer offer,
    RiderProfileSnapshot rider,
  ) async {
    if (_accepting) return;
    setState(() {
      _accepting = true;
      _statusMessage = null;
    });

    final result = await _acceptController.accept(
      jobId: offer.id,
      rider: rider,
    );

    if (!mounted) return;

    setState(() {
      _accepting = false;
      _accepted = result.accepted;
      _statusMessage = result.message;
      _acceptStatus = result.status;
    });

    if (result.accepted) {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      if (_isScheduled(offer) && widget.onScheduledAccepted != null) {
        widget.onScheduledAccepted!();
        setState(() {
          _accepted = false;
          _acceptStatus = null;
          _statusMessage = null;
        });
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RiderAcceptedJobScreen(
            offer: offer,
            firestore: _firestore,
            riderId: rider.riderId,
            riderRank: rider.riderRank ?? 'Agent',
            onNavigateTab: widget.onNavigateTab,
          ),
        ),
      );
    }
  }

  void _resetTakenState() {
    setState(() {
      _acceptStatus = null;
      _statusMessage = null;
      _accepted = false;
      _activeIndex = 0;
    });
  }

  bool _isScheduled(RiderJobOffer offer) =>
      offer.warningChips.contains('Scheduled') ||
      offer.raw['isScheduled'] == true ||
      offer.raw['scheduled'] == true ||
      offer.raw['scheduledAt'] != null;

  Future<void> _acceptPreview(RiderJobOffer offer) async {
    if (_accepting || _accepted) return;
    setState(() => _accepted = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RiderAcceptedJobScreen(offer: offer)),
    );
  }
}

class _OfferExperience extends StatelessWidget {
  final List<RiderJobOffer> offers;
  final int activeIndex;
  final bool accepting;
  final bool accepted;
  final String riderRank;
  final String? statusMessage;
  final RiderAcceptStatus? acceptStatus;
  final VoidCallback onBackToFeed;
  final ValueChanged<int> onIndexChanged;
  final ValueChanged<RiderJobOffer> onAccept;

  const _OfferExperience({
    required this.offers,
    required this.activeIndex,
    required this.accepting,
    required this.accepted,
    required this.riderRank,
    required this.statusMessage,
    required this.acceptStatus,
    required this.onBackToFeed,
    required this.onIndexChanged,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    if (acceptStatus == RiderAcceptStatus.alreadyTaken) {
      return _TakenState(onBackToFeed: onBackToFeed);
    }
    final safeIndex = activeIndex.clamp(0, offers.length - 1);
    final activeOffer = offers[safeIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF07090F),
      body: Stack(
        children: [
          _OfferMapBackground(offer: activeOffer, focusPickup: accepted),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF07090F).withValues(alpha: 0.22),
                  const Color(0xFF07090F).withValues(alpha: 0.72),
                  const Color(0xFF07090F),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                children: [
                  _OfferHeader(count: offers.length, activeIndex: safeIndex),
                  const Spacer(),
                  if (statusMessage != null) ...[
                    _InlineStatus(message: statusMessage!),
                    const SizedBox(height: 12),
                  ],
                  RiderOfferStack(
                    offers: offers,
                    activeIndex: safeIndex,
                    accepting: accepting,
                    accepted: accepted,
                    riderRank: riderRank,
                    onIndexChanged: onIndexChanged,
                    onAccept: onAccept,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TakenState extends StatelessWidget {
  const _TakenState({required this.onBackToFeed});
  final VoidCallback onBackToFeed;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF07090F),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: RiderGlassSurface(
                  padding: const EdgeInsets.all(24),
                  radius: 24,
                  opacity: .70,
                  blur: 20,
                  edgeColor: RiderPalette.red,
                  borderColor: Colors.white.withValues(alpha: .14),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF87171).withValues(alpha: .12),
                      ),
                      child: const Icon(Icons.work_off_outlined,
                          color: Color(0xFFF87171)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Job no longer available',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('Another Rider accepted this delivery first.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .62),
                            height: 1.4)),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: onBackToFeed,
                        child: const Text('Back to job feed'),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

class RiderJobOfferPreview {
  static List<RiderJobOffer> offers() {
    return [
      RiderJobOffer(
        id: 'preview-health',
        requestId: 'CIR-1029',
        pickupArea: 'Marylebone',
        dropoffArea: 'Chelsea',
        pickupAddress: '12 Harley Street, Marylebone, London W1G 9PG',
        dropoffAddress: '41 King\'s Road, Chelsea, London SW3 4NB',
        earnings: 14.80,
        currency: 'GBP',
        pickupDistanceText: '1.2 mi to pickup',
        distanceText: '3.4 mi',
        timeText: '22 min',
        parcelGuidance: 'IRIS: Prescription box - Vanguard included',
        minimumVehicle: 'Bike',
        weightText: '0.2kg',
        pickupTiming: 'ASAP',
        expiryText: 'Expires in 8m',
        irisSummary: 'IRIS 96% match',
        warningChips: const ['Health+', 'Vanguard', 'Scheduled'],
        raw: const {
          'isHealthPlus': true,
          'requiresVanguard': true,
          'isScheduled': true,
          'minimumVehicle': 'Bike',
        },
      ),
      RiderJobOffer(
        id: 'preview-gift',
        requestId: 'CIR-1030',
        pickupArea: 'Soho',
        dropoffArea: 'Battersea',
        pickupAddress: '18 Dean Street, Soho, London W1D 3RL',
        dropoffAddress: '7 Prince of Wales Drive, Battersea, London SW11 4FA',
        earnings: 18.40,
        currency: 'GBP',
        pickupDistanceText: '0.9 mi to pickup',
        distanceText: '4.8 mi',
        timeText: '31 min',
        parcelGuidance: 'IRIS: Gift parcel - Handle carefully',
        minimumVehicle: 'Car',
        weightText: '1.4kg',
        pickupTiming: 'Today 16:30',
        expiryText: 'Expires in 6m',
        irisSummary: 'IRIS gift match',
        warningChips: const ['Gift', 'Vanguard'],
        raw: const {
          'isGift': true,
          'requiresVanguard': true,
          'minimumVehicle': 'Car',
        },
      ),
      RiderJobOffer(
        id: 'preview-business',
        requestId: 'CIR-1031',
        pickupArea: 'Shoreditch',
        dropoffArea: 'Canary Wharf',
        pickupAddress: '55 Great Eastern Street, Shoreditch, London EC2A 3HP',
        dropoffAddress: '20 Bank Street, Canary Wharf, London E14 5JP',
        earnings: 21.50,
        currency: 'GBP',
        pickupDistanceText: '2.1 mi to pickup',
        distanceText: '5.7 mi',
        timeText: '36 min',
        parcelGuidance: 'IRIS: Business documents - Small equipment',
        minimumVehicle: 'Car',
        weightText: '5kg',
        pickupTiming: 'Scheduled',
        expiryText: 'Expires in 10m',
        irisSummary: 'IRIS business documents',
        warningChips: const ['Business', 'Heavy'],
        raw: const {
          'isBusiness': true,
          'isHeavyDuty': true,
          'minimumVehicle': 'Car',
        },
      ),
    ];
  }
}

class _OfferHeader extends StatelessWidget {
  final int count;
  final int activeIndex;

  const _OfferHeader({required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Align(
            alignment: Alignment.centerLeft,
            child: RiderGlassSurface(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              radius: 999,
              opacity: .58,
              blur: 16,
              child: Text(
                '$count Available Offers',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${activeIndex + 1} of $count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Swipe to view more',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OfferMapBackground extends StatefulWidget {
  final RiderJobOffer offer;
  final bool focusPickup;
  final Position? riderPosition;

  const _OfferMapBackground({
    required this.offer,
    this.focusPickup = false,
    this.riderPosition,
  });

  @override
  State<_OfferMapBackground> createState() => _OfferMapBackgroundState();
}

class _OfferMapBackgroundState extends State<_OfferMapBackground> {
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(covariant _OfferMapBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.focusPickup && widget.focusPickup) {
      _focusPickup();
    }
    final oldPosition = oldWidget.riderPosition;
    final nextPosition = widget.riderPosition;
    if (nextPosition != null &&
        (oldPosition == null ||
            Geolocator.distanceBetween(
                  oldPosition.latitude,
                  oldPosition.longitude,
                  nextPosition.latitude,
                  nextPosition.longitude,
                ) >
                8)) {
      _controller?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(nextPosition.latitude, nextPosition.longitude),
        ),
      );
    }
  }

  void _focusPickup() {
    final pickup = _latLng(
        widget.offer.raw['pickupDetails'] ?? widget.offer.raw['pickup']);
    if (pickup == null) return;
    _controller?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: pickup, zoom: 15.5),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pickup = _latLng(
        widget.offer.raw['pickupDetails'] ?? widget.offer.raw['pickup']);
    final dropoff = _latLng(
        widget.offer.raw['dropoffDetails'] ?? widget.offer.raw['dropoff']);

    if (pickup == null || dropoff == null) {
      return const _MapFallback();
    }

    final riderLatLng = widget.riderPosition == null
        ? null
        : LatLng(
            widget.riderPosition!.latitude,
            widget.riderPosition!.longitude,
          );

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) {
            _controller = controller;
            if (widget.focusPickup) {
              _focusPickup();
            } else {
              _fitRoute(pickup, dropoff, riderLatLng);
            }
          },
          initialCameraPosition: CameraPosition(
            target: LatLng(
              (pickup.latitude + dropoff.latitude) / 2,
              (pickup.longitude + dropoff.longitude) / 2,
            ),
            zoom: 12,
          ),
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: true,
          mapToolbarEnabled: false,
          markers: {
            Marker(
              markerId: const MarkerId('pickup'),
              position: pickup,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure),
            ),
            Marker(
              markerId: const MarkerId('dropoff'),
              position: dropoff,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue),
            ),
            if (widget.riderPosition != null)
              Marker(
                markerId: const MarkerId('rider'),
                position: riderLatLng!,
                rotation: widget.riderPosition!.heading.isFinite
                    ? widget.riderPosition!.heading
                    : 0,
                anchor: const Offset(.5, .5),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueCyan),
              ),
          },
          polylines: {
            Polyline(
              polylineId: const PolylineId('route'),
              points: [pickup, dropoff],
              color: const Color(0xFF60A5FA),
              width: 5,
            ),
          },
          circles: {
            if (riderLatLng != null)
              Circle(
                circleId: const CircleId('rider-live-pulse'),
                center: riderLatLng,
                radius: widget.riderPosition!.accuracy.clamp(12, 42).toDouble(),
                fillColor: const Color(0xFF38BDF8).withValues(alpha: .16),
                strokeColor: const Color(0xFF60A5FA).withValues(alpha: .58),
                strokeWidth: 2,
              ),
          },
        ),
        Positioned(
          right: 16,
          top: 112,
          child: Column(
            children: [
              _MapControlButton(
                tooltip: 'Re-centre rider',
                icon: Icons.my_location_rounded,
                onTap: riderLatLng == null
                    ? null
                    : () => _controller?.animateCamera(
                          CameraUpdate.newLatLng(riderLatLng),
                        ),
              ),
              const SizedBox(height: 10),
              _MapControlButton(
                tooltip: 'Fit route',
                icon: Icons.zoom_out_map_rounded,
                onTap: () => _fitRoute(pickup, dropoff, riderLatLng),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _fitRoute(LatLng pickup, LatLng dropoff, LatLng? rider) {
    final points = [pickup, dropoff, if (rider != null) rider];
    final minLat =
        points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat =
        points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final minLng =
        points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final maxLng =
        points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
    _controller?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        68,
      ),
    );
  }

  static LatLng? _latLng(dynamic value) {
    if (value is! Map) return null;
    final position = value['position'];
    if (position is Map) {
      final geo = position['geopoint'] ?? position['geoPoint'];
      if (geo is GeoPoint) return LatLng(geo.latitude, geo.longitude);
      final lat = position['lat'] ?? position['latitude'];
      final lng = position['lng'] ?? position['longitude'];
      if (lat is num && lng is num)
        return LatLng(lat.toDouble(), lng.toDouble());
    }
    final geo = value['geopoint'] ?? value['geoPoint'];
    if (geo is GeoPoint) return LatLng(geo.latitude, geo.longitude);
    final lat = value['lat'] ?? value['latitude'];
    final lng = value['lng'] ?? value['longitude'];
    if (lat is num && lng is num) return LatLng(lat.toDouble(), lng.toDouble());
    return null;
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        enabled: onTap != null,
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: RiderGlassSurface(
              radius: 16,
              opacity: .62,
              blur: 14,
              borderColor: Colors.white.withValues(alpha: .14),
              child: Icon(
                icon,
                color: onTap == null
                    ? Colors.white.withValues(alpha: .28)
                    : const Color(0xFF60A5FA),
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

RiderGeoPoint? _trackingPoint(dynamic value) {
  if (value is! Map) return null;
  final position = value['position'];
  if (position is Map) {
    final geo = position['geopoint'] ?? position['geoPoint'];
    if (geo is GeoPoint) return RiderGeoPoint(geo.latitude, geo.longitude);
    final lat = position['lat'] ?? position['latitude'];
    final lng = position['lng'] ?? position['longitude'];
    if (lat is num && lng is num) {
      return RiderGeoPoint(lat.toDouble(), lng.toDouble());
    }
  }
  final geo = value['geopoint'] ?? value['geoPoint'];
  if (geo is GeoPoint) return RiderGeoPoint(geo.latitude, geo.longitude);
  final lat = value['lat'] ?? value['latitude'];
  final lng = value['lng'] ?? value['longitude'];
  if (lat is num && lng is num) {
    return RiderGeoPoint(lat.toDouble(), lng.toDouble());
  }
  return null;
}

class _MapFallback extends StatelessWidget {
  const _MapFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF07090F),
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.2,
          colors: [
            Color(0x553B82F6),
            Color(0x220B1020),
            Color(0xFF07090F),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _RouteFallbackPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RouteFallbackPainter extends CustomPainter {
  const _RouteFallbackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x + 80, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += 52) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 24), gridPaint);
    }

    final routePaint = Paint()
      ..color = const Color(0xFF60A5FA).withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.28)
      ..cubicTo(
        size.width * 0.62,
        size.height * 0.22,
        size.width * 0.24,
        size.height * 0.62,
        size.width * 0.82,
        size.height * 0.72,
      );
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InlineStatus extends StatelessWidget {
  final String message;

  const _InlineStatus({required this.message});

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 16,
      opacity: .62,
      blur: 18,
      borderColor: const Color(0xFF60A5FA).withValues(alpha: .26),
      child: Text(
        message,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.86),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StateScaffold extends StatelessWidget {
  final String title;
  final String message;
  final bool loading;

  const _StateScaffold({
    required this.title,
    required this.message,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07090F),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading) ...[
                  const CircularProgressIndicator(color: Color(0xFF60A5FA)),
                  const SizedBox(height: 22),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JobsStateScaffold extends StatelessWidget {
  final String title;
  final String message;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _JobsStateScaffold({
    required this.title,
    required this.message,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final offline = title.toLowerCase().contains('offline');
    final error = title.toLowerCase().contains('error');
    return Scaffold(
      backgroundColor: const Color(0xFF07090F),
      body: SafeArea(
        child: RefreshIndicator(
          color: RiderPalette.blue,
          backgroundColor: RiderPalette.panel,
          onRefresh: () async {
            context.read<HomeBloc>()
              ..add(CheckForPushToken())
              ..add(CheckForActiveRequest());
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
                sliver: SliverList.list(
                  children: [
                    const Text(
                      'Jobs',
                      style: TextStyle(
                        color: RiderPalette.paper,
                        fontFamily: RiderTypography.heading,
                        fontSize: 34,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Offers, scheduled work, active deliveries and recent jobs.',
                      style: TextStyle(
                        color: RiderPalette.muted,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    RiderGlassSurface(
                      padding: const EdgeInsets.all(18),
                      radius: 22,
                      opacity: .64,
                      edgeColor: error
                          ? RiderPalette.red
                          : offline
                              ? RiderPalette.amber
                              : RiderPalette.blue,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (error
                                          ? RiderPalette.red
                                          : offline
                                              ? RiderPalette.amber
                                              : RiderPalette.blue)
                                      .withValues(alpha: .14),
                                ),
                                child: loading
                                    ? const Padding(
                                        padding: EdgeInsets.all(11),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: RiderPalette.blue,
                                        ),
                                      )
                                    : Icon(
                                        error
                                            ? Icons.cloud_off_rounded
                                            : offline
                                                ? Icons
                                                    .power_settings_new_rounded
                                                : Icons.radar_rounded,
                                        color: error
                                            ? RiderPalette.red
                                            : offline
                                                ? RiderPalette.amber
                                                : RiderPalette.blue,
                                      ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: RiderPalette.paper,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      message,
                                      style: const TextStyle(
                                        color: RiderPalette.muted,
                                        fontSize: 12.5,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (actionLabel != null) ...[
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: onAction,
                              style: FilledButton.styleFrom(
                                backgroundColor: RiderPalette.blue,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: Text(actionLabel!),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _JobsInfoGrid(offline: offline),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobsInfoGrid extends StatelessWidget {
  const _JobsInfoGrid({required this.offline});

  final bool offline;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _JobsInfoTile(
          icon: Icons.wifi_tethering_rounded,
          title: 'Availability',
          subtitle: offline
              ? 'Offline. Use the centre action to go online.'
              : 'Online status controls nearby offer listening.',
          accent: offline ? RiderPalette.amber : RiderPalette.green,
        ),
        const SizedBox(height: 10),
        const _JobsInfoTile(
          icon: Icons.calendar_month_outlined,
          title: 'Reserved scheduled jobs',
          subtitle: 'Scheduled deliveries stay in Schedule until ready.',
          accent: RiderPalette.purple,
        ),
        const SizedBox(height: 10),
        const _JobsInfoTile(
          icon: Icons.near_me_outlined,
          title: 'Active delivery',
          subtitle: 'Accepted jobs restore into the live delivery flow.',
          accent: RiderPalette.blue,
        ),
        const SizedBox(height: 10),
        const _JobsInfoTile(
          icon: Icons.history_rounded,
          title: 'Recent jobs',
          subtitle:
              'Completed work remains available in activity and earnings.',
          accent: RiderPalette.green,
        ),
      ],
    );
  }
}

class _JobsInfoTile extends StatelessWidget {
  const _JobsInfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      padding: const EdgeInsets.all(15),
      radius: 18,
      opacity: .58,
      blur: 12,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: RiderPalette.paper,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: RiderPalette.muted,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum RiderDeliveryStage {
  accepted,
  navigatingToPickup,
  approachingPickup,
  arrivedAtPickup,
  pickupVerification,
  pickupVerified,
  collected,
  navigatingToDropoff,
  approachingDropoff,
  arrivedAtDropoff,
  waiting,
  pinRequired,
  delivered,
  issueReported,
}

class RiderDeliveryStagePolicy {
  static const ordered = [
    RiderDeliveryStage.accepted,
    RiderDeliveryStage.navigatingToPickup,
    RiderDeliveryStage.approachingPickup,
    RiderDeliveryStage.arrivedAtPickup,
    RiderDeliveryStage.pickupVerification,
    RiderDeliveryStage.pickupVerified,
    RiderDeliveryStage.collected,
    RiderDeliveryStage.navigatingToDropoff,
    RiderDeliveryStage.approachingDropoff,
    RiderDeliveryStage.arrivedAtDropoff,
    RiderDeliveryStage.waiting,
    RiderDeliveryStage.pinRequired,
    RiderDeliveryStage.delivered,
  ];

  static RiderDeliveryStage fromRaw(dynamic value) {
    final text = '$value'.trim().toLowerCase();
    switch (text) {
      case 'navigating_to_pickup':
      case 'travelling_to_pickup':
        return RiderDeliveryStage.navigatingToPickup;
      case 'approaching_pickup':
        return RiderDeliveryStage.approachingPickup;
      case 'arrived_at_pickup':
        return RiderDeliveryStage.arrivedAtPickup;
      case 'pickup_verification':
      case 'parcel_verification_required':
        return RiderDeliveryStage.pickupVerification;
      case 'pickup_verified':
      case 'parcel_verified':
        return RiderDeliveryStage.pickupVerified;
      case 'collected':
        return RiderDeliveryStage.collected;
      case 'navigating_to_dropoff':
      case 'travelling_to_dropoff':
        return RiderDeliveryStage.navigatingToDropoff;
      case 'approaching_dropoff':
      case 'approaching_destination':
        return RiderDeliveryStage.approachingDropoff;
      case 'arrived_at_dropoff':
        return RiderDeliveryStage.arrivedAtDropoff;
      case 'waiting':
        return RiderDeliveryStage.waiting;
      case 'pin_required':
      case 'dropoff_verification_required':
        return RiderDeliveryStage.pinRequired;
      case 'delivered':
        return RiderDeliveryStage.delivered;
      case 'issue_reported':
        return RiderDeliveryStage.issueReported;
      default:
        return RiderDeliveryStage.accepted;
    }
  }

  static String storageValue(RiderDeliveryStage stage) {
    switch (stage) {
      case RiderDeliveryStage.navigatingToPickup:
        return 'navigating_to_pickup';
      case RiderDeliveryStage.approachingPickup:
        return 'approaching_pickup';
      case RiderDeliveryStage.arrivedAtPickup:
        return 'arrived_at_pickup';
      case RiderDeliveryStage.pickupVerification:
        return 'pickup_verification';
      case RiderDeliveryStage.pickupVerified:
        return 'pickup_verified';
      case RiderDeliveryStage.collected:
        return 'collected';
      case RiderDeliveryStage.navigatingToDropoff:
        return 'navigating_to_dropoff';
      case RiderDeliveryStage.approachingDropoff:
        return 'approaching_dropoff';
      case RiderDeliveryStage.arrivedAtDropoff:
        return 'arrived_at_dropoff';
      case RiderDeliveryStage.waiting:
        return 'waiting';
      case RiderDeliveryStage.pinRequired:
        return 'pin_required';
      case RiderDeliveryStage.delivered:
        return 'delivered';
      case RiderDeliveryStage.issueReported:
        return 'issue_reported';
      case RiderDeliveryStage.accepted:
        return 'accepted';
    }
  }

  static RiderDeliveryStage? nextStage(
    RiderDeliveryStage current, {
    required bool verificationRequired,
    required bool pinRequired,
  }) {
    switch (current) {
      case RiderDeliveryStage.accepted:
        return RiderDeliveryStage.navigatingToPickup;
      case RiderDeliveryStage.navigatingToPickup:
      case RiderDeliveryStage.approachingPickup:
        return RiderDeliveryStage.arrivedAtPickup;
      case RiderDeliveryStage.arrivedAtPickup:
        return verificationRequired
            ? RiderDeliveryStage.pickupVerification
            : RiderDeliveryStage.collected;
      case RiderDeliveryStage.pickupVerification:
        return RiderDeliveryStage.pickupVerified;
      case RiderDeliveryStage.pickupVerified:
        return RiderDeliveryStage.collected;
      case RiderDeliveryStage.collected:
        return RiderDeliveryStage.navigatingToDropoff;
      case RiderDeliveryStage.navigatingToDropoff:
      case RiderDeliveryStage.approachingDropoff:
        return RiderDeliveryStage.arrivedAtDropoff;
      case RiderDeliveryStage.arrivedAtDropoff:
        return RiderDeliveryStage.waiting;
      case RiderDeliveryStage.waiting:
        return pinRequired
            ? RiderDeliveryStage.pinRequired
            : RiderDeliveryStage.delivered;
      case RiderDeliveryStage.pinRequired:
        return RiderDeliveryStage.delivered;
      case RiderDeliveryStage.delivered:
      case RiderDeliveryStage.issueReported:
        return null;
    }
  }

  static bool canAdvance({
    required String riderId,
    required Map<String, dynamic> delivery,
    required RiderDeliveryStage current,
    required RiderDeliveryStage target,
    required bool verificationRequired,
    required bool pinRequired,
  }) {
    final assigned =
        '${delivery['riderId'] ?? delivery['assignedRiderId'] ?? ''}'.trim();
    if (assigned.isNotEmpty && assigned != riderId) return false;
    return nextStage(
          current,
          verificationRequired: verificationRequired,
          pinRequired: pinRequired,
        ) ==
        target;
  }

  static Map<String, dynamic> transitionPatch({
    required String deliveryId,
    required String riderId,
    required RiderDeliveryStage from,
    required RiderDeliveryStage to,
    DateTime? now,
    Map<String, dynamic>? arrivalLocation,
  }) {
    final timestamp = now ?? DateTime.now().toUtc();
    final state = storageValue(to);
    final event = {
      'deliveryId': deliveryId,
      'riderId': riderId,
      'previousState': storageValue(from),
      'state': state,
      'updatedBy': riderId,
      'createdAt': Timestamp.fromDate(timestamp),
    };
    final patch = <String, dynamic>{
      'state': state,
      'deliveryStage': state,
      'updatedAt': Timestamp.fromDate(timestamp),
      'updatedBy': riderId,
      'riderId': riderId,
      'validationComplete': to != RiderDeliveryStage.pickupVerification,
      'verificationRequired': to == RiderDeliveryStage.pickupVerification,
      'verificationComplete':
          to.index > RiderDeliveryStage.pickupVerification.index,
      'history': FieldValue.arrayUnion([event]),
    };
    if (to == RiderDeliveryStage.arrivedAtPickup ||
        to == RiderDeliveryStage.arrivedAtDropoff) {
      patch.addAll(_arrivalPatch(
        deliveryId: deliveryId,
        riderId: riderId,
        stage: to,
        timestamp: timestamp,
        arrivalLocation: arrivalLocation,
      ));
    }
    return patch;
  }

  static Map<String, dynamic> _arrivalPatch({
    required String deliveryId,
    required String riderId,
    required RiderDeliveryStage stage,
    required DateTime timestamp,
    Map<String, dynamic>? arrivalLocation,
  }) {
    final isPickup = stage == RiderDeliveryStage.arrivedAtPickup;
    final freeWaitEndsAt = timestamp.add(const Duration(minutes: 3));
    return {
      isPickup ? 'pickupArrivedAt' : 'dropoffArrivedAt':
          Timestamp.fromDate(timestamp),
      'arrivedAt': Timestamp.fromDate(timestamp),
      'arrivalLocation': arrivalLocation,
      'waiting': {
        'active': true,
        'deliveryId': deliveryId,
        'riderId': riderId,
        'phase': isPickup ? 'pickup' : 'dropoff',
        'freeWaitMinutes': 3,
        'startedAt': Timestamp.fromDate(timestamp),
        'freeWaitEndsAt': Timestamp.fromDate(freeWaitEndsAt),
        'noShowAvailableAt': Timestamp.fromDate(freeWaitEndsAt),
      },
      'pendingNotification': {
        'recipient': isPickup ? 'sender' : 'receiver',
        'message': 'Your rider is outside.',
        'triggeredByState': storageValue(stage),
        'createdAt': Timestamp.fromDate(timestamp),
      },
    };
  }

  static bool noShowAvailable(DateTime arrivedAt, DateTime now) {
    return !now.isBefore(arrivedAt.add(const Duration(minutes: 3)));
  }

  static Map<String, dynamic>? waitingChargeRecord({
    required String deliveryId,
    required String riderId,
    required DateTime arrivedAt,
    required DateTime now,
    required int amountPennies,
    String reason = 'waiting_time_after_free_period',
  }) {
    final chargeStart = arrivedAt.add(const Duration(minutes: 3));
    if (now.isBefore(chargeStart)) return null;
    return {
      'chargeType': 'waiting',
      'startTime': Timestamp.fromDate(chargeStart),
      'endTime': Timestamp.fromDate(now),
      'amount': amountPennies,
      'reason': reason,
      'deliveryId': deliveryId,
      'riderId': riderId,
      'auditEvent': {
        'state': 'waiting_charge_recorded',
        'deliveryId': deliveryId,
        'riderId': riderId,
        'createdAt': Timestamp.fromDate(now),
      },
    };
  }
}

class RiderAcceptedJobScreen extends StatefulWidget {
  final RiderJobOffer offer;
  final String riderRank;
  final String riderId;
  final FirebaseFirestore? firestore;
  final RiderDeliveryController? deliveryController;
  final ValueChanged<int>? onNavigateTab;

  const RiderAcceptedJobScreen({
    super.key,
    required this.offer,
    this.riderRank = 'Sentinel',
    this.riderId = 'preview-rider',
    this.firestore,
    this.deliveryController,
    this.onNavigateTab,
  });

  @override
  State<RiderAcceptedJobScreen> createState() => _RiderAcceptedJobScreenState();
}

class _RiderAcceptedJobScreenState extends State<RiderAcceptedJobScreen> {
  late RiderDeliveryStage _stage;
  RiderEvidenceUploader? _evidenceUploader;
  RiderLiveTrackingController? _trackingController;
  StreamSubscription<RiderLiveTrackingSnapshot>? _trackingSub;
  RiderLiveTrackingSnapshot _trackingSnapshot =
      const RiderLiveTrackingSnapshot(status: RiderLiveTrackingStatus.idle);
  Timer? _markerTweenTimer;
  Position? _displayRiderPosition;
  bool _expanded = false;
  bool _transitioning = false;
  bool _arrivalTransitioning = false;
  String? _transitionError;

  bool get _vanguard =>
      widget.offer.warningChips.contains('Vanguard') ||
      widget.offer.raw['requiresVanguard'] == true;
  bool get _pinRequired => _vanguard || widget.offer.raw['pinRequired'] == true;
  bool get _verificationRequired =>
      _vanguard ||
      widget.offer.raw['verificationRequired'] == true ||
      widget.offer.raw['requiresVerification'] == true;
  bool get _proofOfDeliveryRequired =>
      widget.offer.raw['proofOfDeliveryRequired'] == true ||
      widget.offer.raw['requiresProofOfDelivery'] == true ||
      widget.offer.raw['photoProofRequired'] == true ||
      _vanguard;

  @override
  void initState() {
    super.initState();
    if (widget.firestore != null) {
      _trackingController = RiderLiveTrackingController(
        firestore: widget.firestore,
      );
      _trackingSub = _trackingController!.states.listen(_handleTrackingState);
    }
    _stage =
        RiderDeliveryStagePolicy.fromRaw(widget.offer.raw['deliveryStage']);
  }

  @override
  void dispose() {
    _markerTweenTimer?.cancel();
    unawaited(_trackingSub?.cancel());
    _trackingController?.dispose();
    super.dispose();
  }

  void _handleTrackingState(RiderLiveTrackingSnapshot snapshot) {
    if (!mounted) return;
    setState(() => _trackingSnapshot = snapshot);
    if (snapshot.position != null) {
      _animateRiderMarker(snapshot.position!);
    }
    final phase = snapshot.arrivalPhase;
    if (phase == null || _arrivalTransitioning) return;
    if (phase == RiderTrackingArrivalPhase.pickup &&
        (_stage == RiderDeliveryStage.navigatingToPickup ||
            _stage == RiderDeliveryStage.approachingPickup)) {
      unawaited(_autoArrival(RiderDeliveryStage.arrivedAtPickup));
    }
    if (phase == RiderTrackingArrivalPhase.dropoff &&
        (_stage == RiderDeliveryStage.navigatingToDropoff ||
            _stage == RiderDeliveryStage.approachingDropoff)) {
      unawaited(_autoArrival(RiderDeliveryStage.arrivedAtDropoff));
    }
  }

  void _animateRiderMarker(Position next) {
    final previous = _displayRiderPosition ?? next;
    _markerTweenTimer?.cancel();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion || identical(previous, next)) {
      setState(() => _displayRiderPosition = next);
      return;
    }
    const steps = 8;
    var tick = 0;
    _markerTweenTimer =
        Timer.periodic(const Duration(milliseconds: 45), (timer) {
      tick += 1;
      final t = (tick / steps).clamp(0, 1).toDouble();
      final eased = Curves.easeOutCubic.transform(t);
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _displayRiderPosition = Position(
          latitude:
              previous.latitude + (next.latitude - previous.latitude) * eased,
          longitude: previous.longitude +
              (next.longitude - previous.longitude) * eased,
          timestamp: next.timestamp,
          accuracy: next.accuracy,
          altitude: next.altitude,
          altitudeAccuracy: next.altitudeAccuracy,
          heading: next.heading,
          headingAccuracy: next.headingAccuracy,
          speed: next.speed,
          speedAccuracy: next.speedAccuracy,
        );
      });
      if (tick >= steps) timer.cancel();
    });
  }

  Future<void> _advance() async {
    if (_transitioning) return;
    final next = RiderDeliveryStagePolicy.nextStage(
      _stage,
      verificationRequired: _verificationRequired,
      pinRequired: _pinRequired,
    );
    if (next == null) return;
    if (!RiderDeliveryStagePolicy.canAdvance(
      riderId: widget.riderId,
      delivery: widget.offer.raw,
      current: _stage,
      target: next,
      verificationRequired: _verificationRequired,
      pinRequired: _pinRequired,
    )) return;
    final action = _actionForTransition(_stage, next);
    String? pin;
    Map<String, dynamic>? evidence;
    if (_pinRequired &&
        (action == 'verify_collection_pin' ||
            action == 'verify_receiver_pin')) {
      pin = await _requestPin(
        action == 'verify_collection_pin' ? 'Pickup PIN' : 'Delivery PIN',
      );
      if (pin == null) return;
    }
    if ((action == 'verify_collection_pin' && _verificationRequired) ||
        (action == 'verify_receiver_pin' &&
            (_pinRequired || _proofOfDeliveryRequired))) {
      evidence = await _captureEvidence(
        pickup: action == 'verify_collection_pin',
      );
      if (evidence == null) return;
    }
    final controller = widget.deliveryController;
    if (controller == null && widget.firestore == null) {
      setState(() => _stage = next);
      return;
    }
    setState(() {
      _transitioning = true;
      _transitionError = null;
    });
    try {
      final result =
          await (controller ?? CallableRiderDeliveryController()).transition(
        deliveryId: widget.offer.id,
        action: action,
        pin: pin,
        evidence: evidence,
      );
      if (!mounted) return;
      setState(() => _stage = RiderDeliveryStagePolicy.fromRaw(result.status));
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() => _transitionError = error.message ?? 'Action failed.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _transitionError =
          'We could not update this delivery. Check your connection and retry.');
    } finally {
      if (mounted) setState(() => _transitioning = false);
    }
  }

  Future<Map<String, dynamic>?> _captureEvidence({required bool pickup}) async {
    setState(() => _transitioning = true);
    try {
      final photoUrl =
          await (_evidenceUploader ??= RiderEvidenceUploader()).capture(
        deliveryId: widget.offer.id,
        stage: pickup ? 'pickup' : 'handover',
      );
      if (photoUrl == null || !mounted) return null;
      final recipient = TextEditingController();
      final actualWeight = TextEditingController();
      var conditionConfirmed = false;
      var declarationAccepted = false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title:
                Text(pickup ? 'Confirm Pickup Evidence' : 'Confirm Handover'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pickup) ...[
                  CheckboxListTile(
                    value: conditionConfirmed,
                    onChanged: (value) => setDialogState(
                      () => conditionConfirmed = value == true,
                    ),
                    title: const Text('Parcel condition confirmed'),
                  ),
                  CheckboxListTile(
                    value: declarationAccepted,
                    onChanged: (value) => setDialogState(
                      () => declarationAccepted = value == true,
                    ),
                    title: const Text('I confirm this evidence is accurate'),
                  ),
                  if (widget.offer.raw['weightVerificationRequired'] == true)
                    TextField(
                      controller: actualWeight,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Actual weight (kg)'),
                    ),
                ] else
                  TextField(
                    controller: recipient,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Recipient name',
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final valid = pickup
                      ? conditionConfirmed && declarationAccepted
                      : recipient.text.trim().isNotEmpty;
                  if (valid) Navigator.pop(context, true);
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
      final recipientName = recipient.text.trim();
      final actualWeightKg = double.tryParse(actualWeight.text.trim());
      recipient.dispose();
      actualWeight.dispose();
      if (confirmed != true) return null;
      return {
        'photoUrl': photoUrl,
        if (pickup) 'conditionConfirmed': conditionConfirmed,
        if (pickup) 'riderDeclarationAccepted': declarationAccepted,
        if (pickup && actualWeightKg != null) 'actualWeightKg': actualWeightKg,
        if (!pickup) 'recipientName': recipientName,
        if (!pickup) 'recipientConfirmed': true,
      };
    } catch (_) {
      if (mounted) {
        setState(() => _transitionError =
            'Evidence upload failed. Check your connection and retry.');
      }
      return null;
    } finally {
      if (mounted) setState(() => _transitioning = false);
    }
  }

  Future<void> _reportIssue() async {
    final notes = TextEditingController();
    var category = 'other';
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report Delivery Issue'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: category,
                items: const {
                  'sender_unavailable': 'Sender unavailable',
                  'recipient_unavailable': 'Recipient unavailable',
                  'address_problem': 'Address problem',
                  'parcel_mismatch': 'Parcel mismatch',
                  'unsafe_situation': 'Unsafe situation',
                  'damaged_parcel': 'Damaged parcel',
                  'vehicle_suitability': 'Vehicle suitability problem',
                  'other': 'Other',
                }
                    .entries
                    .map((item) => DropdownMenuItem(
                          value: item.key,
                          child: Text(item.value),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => category = value ?? 'other'),
                decoration: const InputDecoration(labelText: 'Issue'),
              ),
              TextField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
    final detail = notes.text.trim();
    notes.dispose();
    if (submit != true) return;
    setState(() => _transitioning = true);
    try {
      final controller =
          widget.deliveryController ?? CallableRiderDeliveryController();
      if (category == 'parcel_mismatch' || category == 'vehicle_suitability') {
        final photoUrl =
            await (_evidenceUploader ??= RiderEvidenceUploader()).capture(
          deliveryId: widget.offer.id,
          stage: 'discrepancy',
        );
        if (photoUrl == null) return;
        await controller.reportDiscrepancy(
          deliveryId: widget.offer.id,
          reason: category == 'vehicle_suitability'
              ? 'dimensions_exceeded'
              : 'item_differs_from_booking',
          evidencePhotos: [photoUrl],
          notes: detail,
        );
        if (mounted) {
          setState(() => _transitionError =
              'Discrepancy submitted for Circum review. Do not collect yet.');
        }
        return;
      }
      final result = await controller.transition(
        deliveryId: widget.offer.id,
        action: 'report_issue',
        issue: {'category': category, 'notes': detail},
      );
      if (mounted) {
        setState(
            () => _stage = RiderDeliveryStagePolicy.fromRaw(result.status));
      }
    } catch (_) {
      if (mounted)
        setState(() => _transitionError = 'Issue report failed. Retry.');
    } finally {
      if (mounted) setState(() => _transitioning = false);
    }
  }

  String _actionForTransition(
    RiderDeliveryStage current,
    RiderDeliveryStage next,
  ) {
    if (current == RiderDeliveryStage.pickupVerified) {
      return 'confirm_collected';
    }
    if (current == RiderDeliveryStage.collected) {
      return 'start_delivery';
    }
    switch (next) {
      case RiderDeliveryStage.navigatingToPickup:
        return 'start_heading_to_pickup';
      case RiderDeliveryStage.approachingPickup:
        return 'start_heading_to_pickup';
      case RiderDeliveryStage.arrivedAtPickup:
        return 'arrived_at_pickup';
      case RiderDeliveryStage.pickupVerification:
      case RiderDeliveryStage.pickupVerified:
      case RiderDeliveryStage.collected:
        return 'verify_collection_pin';
      case RiderDeliveryStage.navigatingToDropoff:
        return 'start_delivery';
      case RiderDeliveryStage.approachingDropoff:
        return 'start_delivery';
      case RiderDeliveryStage.arrivedAtDropoff:
      case RiderDeliveryStage.waiting:
        return 'arrived_at_dropoff';
      case RiderDeliveryStage.pinRequired:
      case RiderDeliveryStage.delivered:
        return 'verify_receiver_pin';
      case RiderDeliveryStage.issueReported:
        return 'report_issue';
      case RiderDeliveryStage.accepted:
        throw StateError('Accepted is not a forward transition.');
    }
  }

  Future<String?> _requestPin(String title) async {
    final input = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Enter 6-digit PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    input.dispose();
    return value != null && RegExp(r'^\d{6}$').hasMatch(value) ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    final firestore = widget.firestore;
    if (firestore == null) return _buildExperience(context, widget.offer.raw);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('deliveryRequests')
          .doc(widget.offer.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const _StateScaffold(
              title: 'Delivery unavailable',
              message:
                  'Check your connection and retry. Your delivery state remains safe.');
        if (!snapshot.hasData)
          return const _StateScaffold(
              title: 'Restoring delivery',
              message: 'Loading the latest operational state.',
              loading: true);
        final live = snapshot.data?.data();
        if (live == null)
          return const _StateScaffold(
              title: 'Delivery unavailable',
              message:
                  'This delivery record is no longer available. Contact Circum Support.');
        final rawStatus =
            live['deliveryStage'] ?? live['deliveryStatus'] ?? live['status'];
        final restored = RiderDeliveryStagePolicy.fromRaw(rawStatus);
        if (restored != _stage)
          scheduleMicrotask(() {
            if (mounted) setState(() => _stage = restored);
          });
        final terminal = '$rawStatus'.toLowerCase();
        if ({'cancelled', 'failed', 'no_show', 'disputed'}.contains(terminal))
          return _StateScaffold(
              title: terminal.replaceAll('_', ' '),
              message:
                  'This delivery can no longer progress. The latest backend state has been restored.');
        scheduleMicrotask(() => _syncLiveTracking(live, restored));
        return _buildExperience(context, live);
      },
    );
  }

  Future<void> _syncLiveTracking(
    Map<String, dynamic> live,
    RiderDeliveryStage stage,
  ) async {
    if (!mounted || widget.firestore == null) return;
    final status = RiderDeliveryStagePolicy.storageValue(stage);
    final terminal = RiderLiveTrackingPolicy.isTerminalDeliveryStatus(status);
    final active = RiderLiveTrackingPolicy.isActiveDeliveryStatus(status);
    final assigned = RiderLiveTrackingPolicy.assignedToRider(
      live,
      widget.riderId,
    );
    if (!active || terminal || !assigned) {
      await _trackingController?.stop(
        status: assigned ? 'inactive' : 'assignment_removed',
      );
      return;
    }
    await _trackingController?.start(
      deliveryId: widget.offer.id,
      riderId: widget.riderId,
      trackingStatus: status,
      pickup: _trackingPoint(
        live['pickupDetails'] ??
            live['pickup'] ??
            widget.offer.raw['pickupDetails'] ??
            widget.offer.raw['pickup'],
      ),
      dropoff: _trackingPoint(
        live['dropoffDetails'] ??
            live['dropoff'] ??
            widget.offer.raw['dropoffDetails'] ??
            widget.offer.raw['dropoff'],
      ),
    );
  }

  Future<void> _autoArrival(RiderDeliveryStage target) async {
    if (!mounted || _transitioning || _arrivalTransitioning) return;
    if (!RiderDeliveryStagePolicy.canAdvance(
      riderId: widget.riderId,
      delivery: widget.offer.raw,
      current: _stage,
      target: target,
      verificationRequired: _verificationRequired,
      pinRequired: _pinRequired,
    )) return;
    setState(() {
      _arrivalTransitioning = true;
      _transitionError = null;
    });
    try {
      final result =
          await (widget.deliveryController ?? CallableRiderDeliveryController())
              .transition(
        deliveryId: widget.offer.id,
        action: target == RiderDeliveryStage.arrivedAtDropoff
            ? 'arrived_at_dropoff'
            : 'arrived_at_pickup',
      );
      if (!mounted) return;
      setState(() => _stage = RiderDeliveryStagePolicy.fromRaw(result.status));
    } catch (_) {
      if (!mounted) return;
      setState(() => _transitionError =
          "Arrival detected, but backend confirmation failed. Tap I've Arrived to retry.");
    } finally {
      if (mounted) setState(() => _arrivalTransitioning = false);
    }
  }

  Widget _buildExperience(BuildContext context, Map<String, dynamic> live) {
    if (_stage == RiderDeliveryStage.delivered)
      return _DeliveryCompleteView(
          offer: widget.offer,
          delivery: live,
          onNavigateTab: widget.onNavigateTab);
    final nextTitle = _nextActionTitle(_stage);
    return Scaffold(
      backgroundColor: const Color(0xFF07090F),
      body: Stack(
        children: [
          _OfferMapBackground(
            offer: widget.offer,
            riderPosition: _displayRiderPosition ?? _trackingSnapshot.position,
            focusPickup: _stage.index < RiderDeliveryStage.collected.index,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF07090F).withValues(alpha: 0.10),
                  const Color(0xFF07090F).withValues(alpha: 0.34),
                  const Color(0xFF07090F).withValues(alpha: 0.78),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                children: [
                  _AcceptedTopPill(chips: widget.offer.warningChips),
                  const SizedBox(height: 14),
                  if (_trackingController != null) ...[
                    _TrackingStatusPill(
                      snapshot: _trackingSnapshot,
                      onRetry: _trackingController?.retry,
                    ),
                    const SizedBox(height: 10),
                    _TrackingEtaCard(
                      offer: widget.offer,
                      snapshot: _trackingSnapshot,
                      stage: _stage,
                    ),
                    const SizedBox(height: 10),
                    if (_TrackingPermissionCard.shouldShow(
                        _trackingSnapshot.status)) ...[
                      _TrackingPermissionCard(
                        snapshot: _trackingSnapshot,
                        onRetry: _trackingController?.retry,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                  _NavigationInstructionCard(
                    title: nextTitle,
                    subtitle: _navigationSubtitle(_stage),
                  ),
                  const SizedBox(height: 10),
                  _CompactProgressIndicator(stage: _stage),
                  if ((_stage == RiderDeliveryStage.arrivedAtPickup ||
                          _stage == RiderDeliveryStage.waiting) &&
                      widget.firestore != null) ...[
                    const SizedBox(height: 10),
                    _WaitingPolicyCard(
                      firestore: widget.firestore!,
                      deliveryId: widget.offer.id,
                      controller: widget.deliveryController ??
                          CallableRiderDeliveryController(),
                    ),
                  ],
                  if (_transitionError != null) ...[
                    const SizedBox(height: 10),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _transitionError!,
                        style: const TextStyle(color: Color(0xFFFF8A8A)),
                      ),
                    ),
                  ],
                  const Spacer(),
                  _AcceptedBottomPanel(
                    offer: widget.offer,
                    riderRank: widget.riderRank,
                    stage: _stage,
                    expanded: _expanded,
                    vanguard: _vanguard,
                    pinRequired: _pinRequired,
                    verificationRequired: _verificationRequired,
                    cta: _transitioning ? 'Updating...' : nextTitle,
                    onToggle: () => setState(() => _expanded = !_expanded),
                    onIssue: _transitioning ? null : _reportIssue,
                    onPrimary: _transitioning ? null : _advance,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _nextActionTitle(RiderDeliveryStage stage) {
    switch (stage) {
      case RiderDeliveryStage.accepted:
        return 'Navigate to Pickup';
      case RiderDeliveryStage.navigatingToPickup:
      case RiderDeliveryStage.approachingPickup:
        return 'I\'ve Arrived';
      case RiderDeliveryStage.arrivedAtPickup:
        return _verificationRequired ? 'Verify Parcel' : 'Confirm Pickup';
      case RiderDeliveryStage.pickupVerification:
        return 'Confirm Pickup';
      case RiderDeliveryStage.pickupVerified:
        return 'Confirm Pickup';
      case RiderDeliveryStage.collected:
        return 'Navigate to Drop-off';
      case RiderDeliveryStage.navigatingToDropoff:
      case RiderDeliveryStage.approachingDropoff:
        return 'I\'ve Arrived';
      case RiderDeliveryStage.arrivedAtDropoff:
      case RiderDeliveryStage.waiting:
        return _pinRequired ? 'Verify PIN' : 'Complete Delivery';
      case RiderDeliveryStage.pinRequired:
        return 'Complete Delivery';
      case RiderDeliveryStage.delivered:
        return 'Delivery Complete';
      case RiderDeliveryStage.issueReported:
        return 'Support Active';
    }
  }

  String _navigationSubtitle(RiderDeliveryStage stage) {
    if (stage.index < RiderDeliveryStage.collected.index) {
      return '${widget.offer.pickupAddress} - ${widget.offer.timeText} away';
    }
    if (stage == RiderDeliveryStage.arrivedAtDropoff ||
        stage == RiderDeliveryStage.waiting) {
      return 'Receiver notified - 3 minute wait timer active';
    }
    if (stage == RiderDeliveryStage.delivered) return widget.offer.dropoffArea;
    return '${widget.offer.dropoffAddress} - ${widget.offer.timeText} away';
  }
}

class _DeliveryCompleteView extends StatelessWidget {
  const _DeliveryCompleteView(
      {required this.offer,
      required this.delivery,
      required this.onNavigateTab});
  final RiderJobOffer offer;
  final Map<String, dynamic> delivery;
  final ValueChanged<int>? onNavigateTab;

  @override
  Widget build(BuildContext context) {
    num value(String key) => delivery[key] is num ? delivery[key] as num : 0;
    final total = value('riderEarning');
    final breakdown = delivery['riderEarningBreakdown'] is Map
        ? Map<String, dynamic>.from(delivery['riderEarningBreakdown'] as Map)
        : const <String, dynamic>{};
    num part(String key) => breakdown[key] is num ? breakdown[key] as num : 0;
    final rothBalance = delivery['rothBalance'] ??
        delivery['currentRothBalance'] ??
        delivery['riderRothBalance'];
    final rothReward = delivery['rothReward'] ??
        delivery['rothEarned'] ??
        delivery['rothTransactionAmount'];
    return Scaffold(
        backgroundColor: const Color(0xFF07090F),
        body: Stack(children: [
          _OfferMapBackground(offer: offer),
          Container(color: const Color(0xFF07090F).withValues(alpha: .78)),
          SafeArea(
              child: Center(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                          constraints: const BoxConstraints(maxWidth: 430),
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                              color: const Color(0xF20D111C),
                              borderRadius: BorderRadius.circular(24),
                              border:
                                  Border.all(color: const Color(0x5534D399))),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const CircleAvatar(
                                radius: 28,
                                backgroundColor: Color(0x2234D399),
                                child: Icon(Icons.check_rounded,
                                    color: Color(0xFF34D399), size: 34)),
                            const SizedBox(height: 14),
                            const Text('Delivery complete',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(
                                'Reference ${delivery['requestId'] ?? offer.id}',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: .62),
                                    fontSize: 12)),
                            const SizedBox(height: 18),
                            _CompletionRow(
                                'Delivery earnings',
                                total -
                                    part('tip') -
                                    part('waiting') -
                                    part('adjustment')),
                            if (part('tip') != 0)
                              _CompletionRow('Tip', part('tip')),
                            if (part('waiting') != 0)
                              _CompletionRow(
                                  'Waiting / no-show', part('waiting')),
                            if (part('adjustment') != 0)
                              _CompletionRow('Adjustment', part('adjustment')),
                            const Divider(color: Colors.white12),
                            _CompletionRow('Total credited', total,
                                strong: true),
                            const SizedBox(height: 8),
                            Text(
                                '+${delivery['trustPointsAwarded'] ?? 0} Trust Points',
                                style: const TextStyle(
                                    color: Color(0xFFA78BFA),
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            _RothCompletionSummary(
                              balance: rothBalance,
                              reward: rothReward,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Delivery chat is now read-only. Support and Admin messages remain visible.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 11),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                    onPressed: () {
                                      onNavigateTab?.call(0);
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Return to Home'))),
                            TextButton(
                                onPressed: () {
                                  onNavigateTab?.call(3);
                                  Navigator.of(context).pop();
                                },
                                child: const Text('View Earnings')),
                            TextButton(
                                onPressed: () {
                                  onNavigateTab?.call(4);
                                  Navigator.of(context).pop();
                                },
                                child: const Text('View Delivery activity')),
                          ])))))
        ]));
  }
}

class _CompletionRow extends StatelessWidget {
  const _CompletionRow(this.label, this.amount, {this.strong = false});
  final String label;
  final num amount;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .7),
                    fontWeight: strong ? FontWeight.w800 : FontWeight.w500))),
        Text('£${amount.toStringAsFixed(2)}',
            style: TextStyle(
                color: Colors.white,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700))
      ]));
}

class _RothCompletionSummary extends StatelessWidget {
  const _RothCompletionSummary({
    required this.balance,
    required this.reward,
  });

  final Object? balance;
  final Object? reward;

  @override
  Widget build(BuildContext context) {
    final balanceText = _formatRoth(balance);
    final rewardText = _formatRoth(reward);
    return Column(
      children: [
        Text(
          rewardText == null
              ? 'Roth balance remains separate from delivery cash.'
              : 'Roth earned: $rewardText',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF60A5FA),
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (balanceText != null)
          Text(
            'Current Roth balance: $balanceText',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
      ],
    );
  }

  static String? _formatRoth(Object? value) {
    if (value == null) return null;
    if (value is num) return '${value.toStringAsFixed(2)} Roth';
    final text = '$value'.trim();
    if (text.isEmpty || text == 'null') return null;
    return text.contains('Roth') ? text : '$text Roth';
  }
}

class _WaitingPolicyCard extends StatelessWidget {
  final FirebaseFirestore firestore;
  final String deliveryId;
  final RiderDeliveryController controller;

  const _WaitingPolicyCard({
    required this.firestore,
    required this.deliveryId,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          firestore.collection('deliveryRequests').doc(deliveryId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final waiting = data['waiting'] is Map
            ? Map<String, dynamic>.from(data['waiting'] as Map)
            : const <String, dynamic>{};
        final rawDeadline = waiting['noShowAvailableAt'];
        final deadline = rawDeadline is Timestamp
            ? rawDeadline.toDate()
            : rawDeadline is num
                ? DateTime.fromMillisecondsSinceEpoch(rawDeadline.toInt())
                : null;
        return StreamBuilder<int>(
          stream: Stream<int>.periodic(
              const Duration(seconds: 1), (value) => value),
          builder: (context, _) {
            final remaining = deadline == null
                ? const Duration(minutes: 3)
                : deadline.difference(DateTime.now());
            final noShowReady = deadline != null && remaining <= Duration.zero;
            final seconds = remaining.isNegative ? 0 : remaining.inSeconds;
            final label =
                '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
            return RiderGlassSurface(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              radius: 18,
              opacity: .64,
              blur: 18,
              borderColor: Colors.white.withValues(alpha: .16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sender notified',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                        Text(
                          noShowReady
                              ? 'No-show review available'
                              : 'Free wait $label',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => controller.reportWaitingContext(
                      deliveryId: deliveryId,
                      type: 'waiting_for_building_access',
                      note: 'Contact established by rider',
                    ),
                    child: const Text('Contact made'),
                  ),
                  if (noShowReady)
                    TextButton(
                      onPressed: () =>
                          controller.markNoShow(deliveryId: deliveryId),
                      child: const Text('No Show'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CompactProgressIndicator extends StatelessWidget {
  final RiderDeliveryStage stage;

  const _CompactProgressIndicator({required this.stage});

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Accepted',
      'Pickup',
      'Verified',
      'Collected',
      'Drop-off',
      'PIN',
      'Delivered',
    ];
    final currentIndex = _progressIndex(stage);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020).withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final complete = index < currentIndex;
          final active = index == currentIndex;
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: complete || active
                        ? const Color(0xFF3B82F6)
                        : Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: complete || active
                          ? const Color(0xFF60A5FA)
                          : Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: complete
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.52),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  static int _progressIndex(RiderDeliveryStage stage) {
    switch (stage) {
      case RiderDeliveryStage.accepted:
        return 0;
      case RiderDeliveryStage.navigatingToPickup:
      case RiderDeliveryStage.approachingPickup:
      case RiderDeliveryStage.arrivedAtPickup:
        return 1;
      case RiderDeliveryStage.pickupVerification:
      case RiderDeliveryStage.pickupVerified:
        return 2;
      case RiderDeliveryStage.collected:
        return 3;
      case RiderDeliveryStage.navigatingToDropoff:
      case RiderDeliveryStage.approachingDropoff:
      case RiderDeliveryStage.arrivedAtDropoff:
      case RiderDeliveryStage.waiting:
        return 4;
      case RiderDeliveryStage.pinRequired:
        return 5;
      case RiderDeliveryStage.delivered:
        return 6;
      case RiderDeliveryStage.issueReported:
        return 4;
    }
  }
}

class _AcceptedTopPill extends StatelessWidget {
  final List<String> chips;

  const _AcceptedTopPill({required this.chips});

  @override
  Widget build(BuildContext context) {
    final labels = chips.where((chip) => chip != 'Standard').take(4).toList();
    if (labels.isEmpty) labels.add('Accepted');
    return Align(
      alignment: Alignment.centerLeft,
      child: RiderGlassSurface(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        radius: 999,
        opacity: .58,
        blur: 16,
        borderColor: const Color(0xFF60A5FA).withValues(alpha: .28),
        child: Text(
          labels.join(' - '),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _TrackingStatusPill extends StatelessWidget {
  const _TrackingStatusPill({
    required this.snapshot,
    required this.onRetry,
  });

  final RiderLiveTrackingSnapshot snapshot;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final color = _color(snapshot.status);
    final warning = color == RiderPalette.amber || color == RiderPalette.red;
    final action = _action(snapshot.status);
    return Semantics(
      label: snapshot.status.accessibilityLabel,
      liveRegion: true,
      child: RiderGlassSurface(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        radius: 999,
        opacity: .62,
        blur: 18,
        borderColor: color.withValues(alpha: warning ? .40 : .30),
        edgeColor: color,
        child: Row(
          children: [
            Icon(_icon(snapshot.status), color: color, size: 16),
            if (snapshot.status == RiderLiveTrackingStatus.live ||
                snapshot.status == RiderLiveTrackingStatus.backgroundActive)
              Container(
                margin: const EdgeInsets.only(left: 5),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: .86),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .42),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ],
                ),
              ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                snapshot.status.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (snapshot.accuracyMeters != null) ...[
              Text(
                '${snapshot.accuracyMeters!.round()}m',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .62),
                  fontSize: 11,
                  fontFamily: RiderTypography.mono,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (action != null)
              GestureDetector(
                onTap: () {
                  if (snapshot.status ==
                      RiderLiveTrackingStatus.permissionPermanentlyDenied) {
                    Geolocator.openAppSettings();
                    return;
                  }
                  if (snapshot.status ==
                      RiderLiveTrackingStatus.servicesDisabled) {
                    Geolocator.openLocationSettings();
                    return;
                  }
                  onRetry?.call();
                },
                child: Text(
                  action,
                  style: const TextStyle(
                    color: Color(0xFF60A5FA),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(RiderLiveTrackingStatus status) {
    return switch (status) {
      RiderLiveTrackingStatus.live ||
      RiderLiveTrackingStatus.backgroundActive =>
        Icons.radar_rounded,
      RiderLiveTrackingStatus.acquiring => Icons.gps_fixed_rounded,
      RiderLiveTrackingStatus.poorAccuracy => Icons.gps_not_fixed_rounded,
      RiderLiveTrackingStatus.foregroundOnly => Icons.phone_iphone_rounded,
      RiderLiveTrackingStatus.offline => Icons.cloud_off_rounded,
      RiderLiveTrackingStatus.reconnecting => Icons.sync_rounded,
      RiderLiveTrackingStatus.permissionRequired ||
      RiderLiveTrackingStatus.permissionDenied ||
      RiderLiveTrackingStatus.permissionPermanentlyDenied =>
        Icons.location_disabled_rounded,
      RiderLiveTrackingStatus.servicesDisabled => Icons.location_off_rounded,
      RiderLiveTrackingStatus.arrivedAtPickup ||
      RiderLiveTrackingStatus.arrivedAtDropoff =>
        Icons.where_to_vote_rounded,
      RiderLiveTrackingStatus.stopped ||
      RiderLiveTrackingStatus.idle =>
        Icons.pause_circle_outline_rounded,
      RiderLiveTrackingStatus.error => Icons.error_outline_rounded,
    };
  }

  static Color _color(RiderLiveTrackingStatus status) {
    return switch (status) {
      RiderLiveTrackingStatus.live ||
      RiderLiveTrackingStatus.backgroundActive ||
      RiderLiveTrackingStatus.arrivedAtPickup ||
      RiderLiveTrackingStatus.arrivedAtDropoff =>
        RiderPalette.blue,
      RiderLiveTrackingStatus.acquiring ||
      RiderLiveTrackingStatus.poorAccuracy ||
      RiderLiveTrackingStatus.foregroundOnly ||
      RiderLiveTrackingStatus.offline ||
      RiderLiveTrackingStatus.reconnecting =>
        RiderPalette.amber,
      RiderLiveTrackingStatus.permissionRequired ||
      RiderLiveTrackingStatus.permissionDenied ||
      RiderLiveTrackingStatus.permissionPermanentlyDenied ||
      RiderLiveTrackingStatus.servicesDisabled ||
      RiderLiveTrackingStatus.error =>
        RiderPalette.red,
      RiderLiveTrackingStatus.stopped ||
      RiderLiveTrackingStatus.idle =>
        RiderPalette.muted,
    };
  }

  static String? _action(RiderLiveTrackingStatus status) {
    switch (status) {
      case RiderLiveTrackingStatus.permissionRequired:
      case RiderLiveTrackingStatus.permissionDenied:
      case RiderLiveTrackingStatus.error:
      case RiderLiveTrackingStatus.offline:
      case RiderLiveTrackingStatus.reconnecting:
        return 'Retry';
      case RiderLiveTrackingStatus.permissionPermanentlyDenied:
      case RiderLiveTrackingStatus.servicesDisabled:
        return 'Settings';
      default:
        return null;
    }
  }
}

class _TrackingEtaCard extends StatelessWidget {
  const _TrackingEtaCard({
    required this.offer,
    required this.snapshot,
    required this.stage,
  });

  final RiderJobOffer offer;
  final RiderLiveTrackingSnapshot snapshot;
  final RiderDeliveryStage stage;

  @override
  Widget build(BuildContext context) {
    final toDropoff = stage.index >= RiderDeliveryStage.collected.index;
    final label = toDropoff ? 'To drop-off' : 'To pickup';
    final lastRefresh = _lastRefreshLabel(snapshot.lastPublishedAt);
    final subdued = snapshot.status == RiderLiveTrackingStatus.offline ||
        snapshot.status == RiderLiveTrackingStatus.reconnecting ||
        snapshot.status == RiderLiveTrackingStatus.stopped ||
        snapshot.status == RiderLiveTrackingStatus.idle;
    return RiderGlassSurface(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 22,
      opacity: subdued ? .70 : .58,
      blur: 18,
      borderColor: const Color(0xFF60A5FA).withValues(alpha: .24),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF38BDF8).withValues(alpha: .14),
              border: Border.all(
                color: const Color(0xFF60A5FA).withValues(alpha: .28),
              ),
            ),
            child: Icon(
              toDropoff ? Icons.flag_circle_rounded : Icons.my_location_rounded,
              color: const Color(0xFF60A5FA),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .64),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          offer.timeText.isEmpty
                              ? 'ETA unavailable'
                              : offer.timeText,
                          key: ValueKey(offer.timeText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontFamily: RiderTypography.mono,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        offer.distanceText.isEmpty
                            ? 'Route loading'
                            : offer.distanceText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .72),
                          fontSize: 12,
                          fontFamily: RiderTypography.mono,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (lastRefresh != null) ...[
            const SizedBox(width: 10),
            Text(
              lastRefresh,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .50),
                fontSize: 10,
                fontFamily: RiderTypography.mono,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String? _lastRefreshLabel(DateTime? value) {
    if (value == null) return null;
    final elapsed = DateTime.now().difference(value);
    if (elapsed.inSeconds < 10) return 'now';
    if (elapsed.inMinutes < 1) return '${elapsed.inSeconds}s';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}m';
    return '${elapsed.inHours}h';
  }
}

class _TrackingPermissionCard extends StatelessWidget {
  const _TrackingPermissionCard({
    required this.snapshot,
    required this.onRetry,
  });

  final RiderLiveTrackingSnapshot snapshot;
  final Future<void> Function()? onRetry;

  static bool shouldShow(RiderLiveTrackingStatus status) {
    return switch (status) {
      RiderLiveTrackingStatus.permissionRequired ||
      RiderLiveTrackingStatus.permissionDenied ||
      RiderLiveTrackingStatus.permissionPermanentlyDenied ||
      RiderLiveTrackingStatus.servicesDisabled ||
      RiderLiveTrackingStatus.foregroundOnly ||
      RiderLiveTrackingStatus.poorAccuracy ||
      RiderLiveTrackingStatus.offline ||
      RiderLiveTrackingStatus.reconnecting =>
        true,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final actionLabel = _actionLabel(snapshot.status);
    return Semantics(
      label: snapshot.status.accessibilityLabel,
      liveRegion: true,
      child: RiderGlassSurface(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        radius: 22,
        opacity: .72,
        blur: 18,
        borderColor: _color(snapshot.status).withValues(alpha: .30),
        edgeColor: _color(snapshot.status),
        child: Row(
          children: [
            Icon(
              _icon(snapshot.status),
              color: _color(snapshot.status),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot.status.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    snapshot.message ?? snapshot.status.supportingText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .68),
                      fontSize: 12,
                      height: 1.28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(width: 10),
              TextButton(
                onPressed: _onAction,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  foregroundColor: const Color(0xFF60A5FA),
                ),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  VoidCallback? get _onAction {
    switch (snapshot.status) {
      case RiderLiveTrackingStatus.permissionPermanentlyDenied:
        return () => Geolocator.openAppSettings();
      case RiderLiveTrackingStatus.servicesDisabled:
        return () => Geolocator.openLocationSettings();
      case RiderLiveTrackingStatus.permissionRequired:
      case RiderLiveTrackingStatus.permissionDenied:
      case RiderLiveTrackingStatus.offline:
      case RiderLiveTrackingStatus.reconnecting:
      case RiderLiveTrackingStatus.poorAccuracy:
        return () => onRetry?.call();
      default:
        return null;
    }
  }

  static String? _actionLabel(RiderLiveTrackingStatus status) {
    return switch (status) {
      RiderLiveTrackingStatus.permissionPermanentlyDenied ||
      RiderLiveTrackingStatus.servicesDisabled =>
        'Settings',
      RiderLiveTrackingStatus.permissionRequired ||
      RiderLiveTrackingStatus.permissionDenied ||
      RiderLiveTrackingStatus.offline ||
      RiderLiveTrackingStatus.reconnecting ||
      RiderLiveTrackingStatus.poorAccuracy =>
        'Retry',
      _ => null,
    };
  }

  static IconData _icon(RiderLiveTrackingStatus status) {
    return switch (status) {
      RiderLiveTrackingStatus.permissionRequired ||
      RiderLiveTrackingStatus.permissionDenied ||
      RiderLiveTrackingStatus.permissionPermanentlyDenied =>
        Icons.location_disabled_rounded,
      RiderLiveTrackingStatus.servicesDisabled => Icons.location_off_rounded,
      RiderLiveTrackingStatus.foregroundOnly => Icons.phone_iphone_rounded,
      RiderLiveTrackingStatus.poorAccuracy => Icons.gps_not_fixed_rounded,
      RiderLiveTrackingStatus.offline => Icons.cloud_off_rounded,
      RiderLiveTrackingStatus.reconnecting => Icons.sync_rounded,
      _ => Icons.info_outline_rounded,
    };
  }

  static Color _color(RiderLiveTrackingStatus status) {
    return switch (status) {
      RiderLiveTrackingStatus.poorAccuracy ||
      RiderLiveTrackingStatus.foregroundOnly ||
      RiderLiveTrackingStatus.offline ||
      RiderLiveTrackingStatus.reconnecting =>
        RiderPalette.amber,
      RiderLiveTrackingStatus.permissionRequired ||
      RiderLiveTrackingStatus.permissionDenied ||
      RiderLiveTrackingStatus.permissionPermanentlyDenied ||
      RiderLiveTrackingStatus.servicesDisabled =>
        RiderPalette.red,
      _ => RiderPalette.blue,
    };
  }
}

class _NavigationInstructionCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _NavigationInstructionCard(
      {required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      radius: 24,
      opacity: .62,
      blur: 20,
      borderColor: const Color(0xFF60A5FA).withValues(alpha: .26),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                const Icon(Icons.navigation_rounded, color: Color(0xFF60A5FA)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AcceptedBottomPanel extends StatelessWidget {
  final RiderJobOffer offer;
  final String riderRank;
  final RiderDeliveryStage stage;
  final bool expanded;
  final bool vanguard;
  final bool pinRequired;
  final bool verificationRequired;
  final String cta;
  final VoidCallback onToggle;
  final VoidCallback? onPrimary;
  final VoidCallback? onIssue;

  const _AcceptedBottomPanel({
    required this.offer,
    required this.riderRank,
    required this.stage,
    required this.expanded,
    required this.vanguard,
    required this.pinRequired,
    required this.verificationRequired,
    required this.cta,
    required this.onToggle,
    required this.onPrimary,
    required this.onIssue,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: expanded ? 560 : 330),
        child: RiderGlassSurface(
          padding: const EdgeInsets.all(18),
          radius: 28,
          opacity: .66,
          blur: 22,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                key: const Key('accepted_panel_toggle'),
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: SizedBox(
                  width: double.infinity,
                  height: 20,
                  child: Center(
                    child: Container(
                      width: 46,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _AcceptedEssentialSummary(
                offer: offer,
                riderRank: riderRank,
                cta: cta,
                onPrimary: onPrimary,
              ),
              if (expanded) ...[
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (vanguard) ...[
                          const _VanguardGuidance(),
                          const SizedBox(height: 10),
                        ],
                        _DeliveryPartyAndInstructionPanel(
                          offer: offer,
                          stage: stage,
                        ),
                        const SizedBox(height: 10),
                        _ExpandedLine(
                            title: 'Pickup', body: offer.pickupAddress),
                        _ExpandedLine(
                            title: 'Drop-off', body: offer.dropoffAddress),
                        _PinAndIrisPanel(
                          offer: offer,
                          vanguard: vanguard,
                          pinRequired: pinRequired,
                          verificationRequired: verificationRequired,
                        ),
                        _PickupWorkflowPanel(
                          vanguard: vanguard,
                          verificationRequired: verificationRequired,
                        ),
                        const SizedBox(height: 10),
                        _ExpandedLine(
                          title: 'Verification',
                          body: verificationRequired
                              ? 'Parcel condition verification is required before collection.'
                              : 'Check parcel condition at pickup.',
                        ),
                        _StageTracker(
                            stage: stage,
                            verificationRequired: verificationRequired),
                        const SizedBox(height: 10),
                        _SecondaryContactRow(
                          offer: offer,
                          stage: stage,
                          vanguard: vanguard,
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: onIssue,
                          icon: const Icon(Icons.report_outlined),
                          label: const Text('Report an issue'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AcceptedEssentialSummary extends StatelessWidget {
  final RiderJobOffer offer;
  final String riderRank;
  final String cta;
  final VoidCallback? onPrimary;

  const _AcceptedEssentialSummary({
    required this.offer,
    required this.riderRank,
    required this.cta,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final points = offer.points.points;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(_money(offer.earnings, offer.currency),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900)),
            ),
            Text(riderRank,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 2),
        Text('+$points Trust',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 11),
        Text(_collapsedChips(offer),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text('${offer.pickupArea} → ${offer.dropoffArea}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('${offer.parcelGuidance} - ${offer.weightText}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Vehicle: ${offer.minimumVehicle} - Pickup: ${offer.pickupTiming}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 12,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: onPrimary,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17)),
            ),
            child: Text(cta,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }

  static String _money(double value, String currency) {
    final symbol = currency.toUpperCase() == 'GBP' ? '£' : '$currency ';
    return '$symbol${value.toStringAsFixed(2)}';
  }

  static String _collapsedChips(RiderJobOffer offer) {
    final chips =
        offer.warningChips.where((chip) => chip != 'Standard').take(3).toList();
    chips.add(offer.minimumVehicle);
    return chips.join(' - ');
  }
}

class _VanguardGuidance extends StatelessWidget {
  const _VanguardGuidance();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.26)),
      ),
      child: const Text(
        'Vanguard Protection\nThis delivery requires enhanced handling. Follow IRIS handling guidance, verify parcel condition, maintain secure custody, and complete every required verification step.',
        style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DeliveryPartyAndInstructionPanel extends StatelessWidget {
  const _DeliveryPartyAndInstructionPanel({
    required this.offer,
    required this.stage,
  });

  final RiderJobOffer offer;
  final RiderDeliveryStage stage;

  @override
  Widget build(BuildContext context) {
    final raw = offer.raw;
    final headingToDropoff = stage.index >= RiderDeliveryStage.collected.index;
    final partyTitle = headingToDropoff ? 'Recipient' : 'Sender';
    final partyName = _firstText(
        raw,
        headingToDropoff
            ? const ['recipientName', 'receiverName', 'dropoffContactName']
            : const ['senderName', 'pickupContactName', 'customerName']);
    final instructions = _firstText(
        raw,
        headingToDropoff
            ? const ['recipientInstructions', 'dropoffInstructions']
            : const ['senderInstructions', 'pickupInstructions']);
    final access = _firstText(raw, const [
      'buildingAccess',
      'accessDetails',
      'entryInstructions',
      'dropoffAccessDetails',
      'pickupAccessDetails',
    ]);
    final parking = _firstText(raw, const [
      'safeParkingNotes',
      'parkingNotes',
      'riderParkingNotes',
    ]);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OperationalLine(
            title: partyTitle,
            body: partyName.isEmpty
                ? 'Shown when provided by booking'
                : partyName,
          ),
          if (instructions.isNotEmpty)
            _OperationalLine(title: 'Instructions', body: instructions),
          if (access.isNotEmpty)
            _OperationalLine(title: 'Building access', body: access),
          if (parking.isNotEmpty)
            _OperationalLine(title: 'Safe parking', body: parking),
          if (instructions.isEmpty && access.isEmpty && parking.isEmpty)
            Text(
              'No extra access, parking or handover notes were provided.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _PinAndIrisPanel extends StatelessWidget {
  const _PinAndIrisPanel({
    required this.offer,
    required this.vanguard,
    required this.pinRequired,
    required this.verificationRequired,
  });

  final RiderJobOffer offer;
  final bool vanguard;
  final bool pinRequired;
  final bool verificationRequired;

  @override
  Widget build(BuildContext context) {
    final raw = offer.raw;
    final quantity = _firstText(raw, const ['quantity', 'itemQuantity']);
    final handling = _firstText(raw, const [
      'handlingInstructions',
      'irisHandling',
      'handlingRequirements',
    ]);
    final valueState = raw['highValue'] == true || raw['isHighValue'] == true
        ? 'High value'
        : '';
    final fragile =
        raw['fragile'] == true || raw['isFragile'] == true ? 'Fragile' : '';
    final senderPin = raw['senderPinRequired'] == true ||
        raw['pickupPinRequired'] == true ||
        pinRequired;
    final receiverPin = raw['receiverPinRequired'] == true ||
        raw['recipientPinRequired'] == true ||
        pinRequired;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'IRIS Brief',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _OperationalLine(
            title: 'Matched item',
            body: offer.parcelGuidance,
            mono: false,
          ),
          _OperationalLine(
            title: 'Quantity',
            body: quantity.isEmpty ? 'Confirm at pickup' : quantity,
            mono: true,
          ),
          _OperationalLine(
            title: 'Weight and vehicle',
            body: '${offer.weightText} - ${offer.minimumVehicle}',
          ),
          if (handling.isNotEmpty)
            _OperationalLine(title: 'Handling', body: handling),
          if (fragile.isNotEmpty || valueState.isNotEmpty || vanguard)
            _OperationalLine(
              title: 'Indicators',
              body: [
                if (fragile.isNotEmpty) fragile,
                if (valueState.isNotEmpty) valueState,
                if (vanguard) 'Vanguard protected',
              ].join(' - '),
            ),
          _OperationalLine(
            title: 'Sender PIN',
            body: senderPin
                ? 'Required before collection. Never show recipient PIN here.'
                : 'Not required for collection',
            mono: senderPin,
          ),
          _OperationalLine(
            title: 'Recipient PIN',
            body: receiverPin
                ? 'Required before completion. Kept separate from Sender PIN.'
                : 'Not required for completion',
            mono: receiverPin,
          ),
          if (verificationRequired)
            const Text(
              'Rider verification is not final truth. Material mismatch escalates to Circum operations.',
              style: TextStyle(
                color: Color(0xFFF5A623),
                fontSize: 11.5,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _OperationalLine extends StatelessWidget {
  const _OperationalLine({
    required this.title,
    required this.body,
    this.mono = false,
  });

  final String title;
  final String body;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.56),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              body,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 12,
                height: 1.28,
                fontFamily: mono ? RiderTypography.mono : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _firstText(Map<String, dynamic> raw, List<String> keys) {
  for (final key in keys) {
    final value = raw[key];
    if (value is num) return '$value';
    final text = '$value'.trim();
    if (text.isNotEmpty && text != 'null') return text;
  }
  return '';
}

class _ExpandedLine extends StatelessWidget {
  final String title;
  final String body;

  const _ExpandedLine({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(body,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PickupWorkflowPanel extends StatelessWidget {
  final bool vanguard;
  final bool verificationRequired;

  const _PickupWorkflowPanel({
    required this.vanguard,
    required this.verificationRequired,
  });

  @override
  Widget build(BuildContext context) {
    final steps = vanguard || verificationRequired
        ? const [
            'Parcel condition',
            'Photo verification',
            'Weight verification where enabled',
            'Sender PIN where required',
            'Package seal confirmation',
          ]
        : const [
            'Confirm parcel matches booking',
            'Add parcel photo if required',
            'Confirm collection',
          ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vanguard ? 'Pickup Verification' : 'Pickup Workflow',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('✓ ',
                      style: TextStyle(
                          color: Color(0xFF60A5FA),
                          fontSize: 12,
                          fontWeight: FontWeight.w900)),
                  Expanded(
                    child: Text(
                      step,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageTracker extends StatelessWidget {
  final RiderDeliveryStage stage;
  final bool verificationRequired;

  const _StageTracker(
      {required this.stage, required this.verificationRequired});

  @override
  Widget build(BuildContext context) {
    final labels = [
      'Accepted',
      'Navigate to Pickup',
      'I\'ve Arrived',
      'Verify Parcel',
      'Collected Parcel',
      'Navigate to Drop-off',
      'Verify PIN',
      'Delivery Complete',
    ];
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: labels.map((label) {
        final active = label == _activeLabel(stage);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF3B82F6).withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: active
                    ? const Color(0xFF60A5FA).withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.08)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.58),
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        );
      }).toList(),
    );
  }

  static String _activeLabel(RiderDeliveryStage stage) {
    switch (stage) {
      case RiderDeliveryStage.accepted:
        return 'Accepted';
      case RiderDeliveryStage.navigatingToPickup:
      case RiderDeliveryStage.approachingPickup:
        return 'Navigate to Pickup';
      case RiderDeliveryStage.arrivedAtPickup:
        return 'I\'ve Arrived';
      case RiderDeliveryStage.pickupVerification:
      case RiderDeliveryStage.pickupVerified:
        return 'Verify Parcel';
      case RiderDeliveryStage.collected:
        return 'Collected Parcel';
      case RiderDeliveryStage.navigatingToDropoff:
      case RiderDeliveryStage.approachingDropoff:
        return 'Navigate to Drop-off';
      case RiderDeliveryStage.arrivedAtDropoff:
        return 'I\'ve Arrived';
      case RiderDeliveryStage.waiting:
      case RiderDeliveryStage.pinRequired:
        return 'Verify PIN';
      case RiderDeliveryStage.delivered:
        return 'Delivery Complete';
      case RiderDeliveryStage.issueReported:
        return 'Support Active';
    }
  }
}

class _SecondaryContactRow extends StatelessWidget {
  final RiderJobOffer offer;
  final RiderDeliveryStage stage;
  final bool vanguard;

  const _SecondaryContactRow({
    required this.offer,
    required this.stage,
    required this.vanguard,
  });

  @override
  Widget build(BuildContext context) {
    final recipientPhase = stage.index >= RiderDeliveryStage.collected.index;
    return Row(
      children: [
        Expanded(
            child: _SecondaryButton(
                icon: Icons.call_rounded,
                label: recipientPhase ? 'Call Recipient' : 'Call Sender',
                onTap: () => _call(offer.raw, recipient: recipientPhase))),
        const SizedBox(width: 8),
        Expanded(
            child: _SecondaryButton(
                icon: Icons.chat_bubble_rounded,
                label: 'Message',
                onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => RiderConversationView(
                                chatId: offer.requestId,
                                title: 'Delivery chat',
                                subtitle:
                                    '${offer.pickupArea} to ${offer.dropoffArea}',
                              )),
                    ))),
        const SizedBox(width: 8),
        Expanded(
          child: _SecondaryButton(
            icon: Icons.support_agent_rounded,
            label: vanguard ? 'Support - Vanguard Priority' : 'Support',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportView()),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SecondaryButton(
            icon: Icons.health_and_safety_rounded,
            label: 'Emergency',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportView()),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _call(Map<String, dynamic> raw,
      {required bool recipient}) async {
    final number = (recipient
            ? '${raw['recipientPhone'] ?? raw['receiverPhone'] ?? raw['dropoffPhone'] ?? ''}'
            : '${raw['senderPhone'] ?? raw['pickupPhone'] ?? raw['contactPhone'] ?? ''}')
        .replaceAll(RegExp(r'[^0-9+]'), '');
    if (number.isEmpty) return;
    await launchUrl(Uri.parse('tel:$number'));
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF60A5FA), size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
