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
import '../rider_internal_access/rider_internal_access.dart';
import '../rider_design/rider_ui.dart';
import '../rider_truth/rider_truth.dart';
import '../support/view/support.dart';
import '../tracking/rider_live_tracking_controller.dart';
import 'rider_accept_controller.dart';
import 'rider_delivery_controller.dart';
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
        future: RiderInternalAccess.enabled(),
        builder: (context, internalAccessSnapshot) {
          final internalAccess = internalAccessSnapshot.data == true;
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('riders').doc(user.uid).snapshots(),
            builder: (context, riderSnapshot) {
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _firestore
                    .collection('riderProfiles')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, profileSnapshot) {
                  final riderData = <String, dynamic>{
                    ...?profileSnapshot.data?.data(),
                    ...?riderSnapshot.data?.data()
                  };
                  final rider = _riderProfile(user.uid, riderData,
                      internalAccess: internalAccess);
                  final online = {'online', 'available', 'busy'}.contains(
                      '${riderData['availabilityStatus'] ?? riderData['status'] ?? ''}'
                          .toLowerCase());

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
                        riderId: user.uid,
                        riderVehicle: rider.riderVehicle,
                        internalAccess: internalAccess,
                      );

                      if (_activeIndex >= offers.length && offers.isNotEmpty) {
                        scheduleMicrotask(() {
                          if (mounted)
                            setState(() => _activeIndex = offers.length - 1);
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
        });
  }

  RiderProfileSnapshot _riderProfile(String uid, Map<String, dynamic> riderData,
      {bool internalAccess = false}) {
    final canAccept =
        internalAccess || RiderOnboardingPolicy.canAcceptJobs(riderData);
    final firstName = '${riderData['firstName'] ?? ''}'.trim();
    final lastName = '${riderData['lastName'] ?? ''}'.trim();
    final displayName =
        [firstName, lastName].where((part) => part.isNotEmpty).join(' ').trim();
    final vehicle = riderData['vehicle'] is Map
        ? '${riderData['vehicle']['type'] ?? riderData['vehicleType'] ?? ''}'
        : '${riderData['vehicleType'] ?? riderData['typeOfVehicle'] ?? ''}';

    return RiderProfileSnapshot(
      riderId: uid,
      riderName: displayName.isEmpty ? null : displayName,
      riderVehicle: vehicle.trim().isEmpty ? null : vehicle.trim(),
      riderRank: RiderRankSnapshot.from(riderData)?.rank,
      canAcceptJobs: canAccept,
      blockedReason:
          canAccept ? null : RiderOnboardingPolicy.blockedReason(riderData),
    );
  }

  List<RiderJobOffer> _filterOffers({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String riderId,
    required String? riderVehicle,
    bool internalAccess = false,
  }) {
    return docs
        .where((doc) => _isVisibleToRider(doc.data(), riderId, riderVehicle,
            internalAccess: internalAccess))
        .map((doc) =>
            RiderJobOffer.fromFirestore(docId: doc.id, data: doc.data()))
        .toList();
  }

  bool _isVisibleToRider(
      Map<String, dynamic> data, String riderId, String? riderVehicle,
      {bool internalAccess = false}) {
    final ignored = _stringList(data['ignoredRiders']);
    final rejected = _stringList(data['rejectedRiders']);
    if (ignored.contains(riderId) || rejected.contains(riderId)) return false;

    final matchingStatus =
        '${data['matchingStatus'] ?? 'available'}'.trim().toLowerCase();
    if (matchingStatus != 'available' && matchingStatus != 'requested') {
      return false;
    }

    final minimumVehicle =
        '${data['minimumVehicle'] ?? data['recommendedVehicle'] ?? 'Bike'}';
    return internalAccess ||
        _vehicleMeetsMinimum(riderVehicle ?? 'Bike', minimumVehicle);
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

  bool _vehicleMeetsMinimum(String riderVehicle, String minimumVehicle) {
    int rank(String value) {
      final normalized = value.trim().toLowerCase();
      if (normalized.contains('van')) return 3;
      if (normalized.contains('car')) return 2;
      return 1;
    }

    return rank(riderVehicle) >= rank(minimumVehicle);
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
        distanceText: '3.4 mi',
        timeText: '22 min',
        parcelGuidance: 'IRIS: Prescription box - Vanguard included',
        minimumVehicle: 'Bike',
        weightText: '0.2kg',
        pickupTiming: 'ASAP',
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
        distanceText: '4.8 mi',
        timeText: '31 min',
        parcelGuidance: 'IRIS: Gift parcel - Handle carefully',
        minimumVehicle: 'Car',
        weightText: '1.4kg',
        pickupTiming: 'Today 16:30',
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
        distanceText: '5.7 mi',
        timeText: '36 min',
        parcelGuidance: 'IRIS: Business documents - Small equipment',
        minimumVehicle: 'Car',
        weightText: '5kg',
        pickupTiming: 'Scheduled',
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

    return GoogleMap(
      onMapCreated: (controller) {
        _controller = controller;
        if (widget.focusPickup) _focusPickup();
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
      compassEnabled: false,
      mapToolbarEnabled: false,
      markers: {
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoff,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
        if (widget.riderPosition != null)
          Marker(
            markerId: const MarkerId('rider'),
            position: riderLatLng!,
            rotation: widget.riderPosition!.heading.isFinite
                ? widget.riderPosition!.heading
                : 0,
            anchor: const Offset(.5, .5),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
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
                      'Available deliveries, scheduled work, active deliveries and activity.',
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
          title: 'Available deliveries',
          subtitle: offline
              ? 'Go online from Home to receive new offers.'
              : 'New offers will appear here automatically.',
          accent: offline ? RiderPalette.amber : RiderPalette.green,
        ),
        const SizedBox(height: 10),
        const _JobsInfoTile(
          icon: Icons.calendar_month_outlined,
          title: 'Scheduled deliveries',
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
          title: 'Activity',
          subtitle:
              'Completed deliveries remain available in activity and earnings.',
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
  arrivedAtPickup,
  pickupVerification,
  pickupVerified,
  collected,
  navigatingToDropoff,
  arrivedAtDropoff,
  waiting,
  pinRequired,
  delivered,
  issueReported,
}

class RiderDeliveryStagePolicy {
  static RiderDeliveryStage fromRaw(dynamic value) {
    final text = '$value'.trim().toLowerCase();
    switch (text) {
      case 'navigating_to_pickup':
        return RiderDeliveryStage.navigatingToPickup;
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
        return RiderDeliveryStage.navigatingToDropoff;
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
  bool _confirmingIris = false;
  bool _irisConfirmedFromBackend = false;
  String? _transitionError;

  bool get _vanguard =>
      widget.offer.warningChips.contains('Vanguard') ||
      widget.offer.raw['requiresVanguard'] == true;
  bool get _healthPlus =>
      widget.offer.warningChips.contains('Health+') ||
      widget.offer.raw['serviceType'] == 'health_plus' ||
      widget.offer.raw['isHealthPlus'] == true;
  bool get _gift =>
      widget.offer.warningChips.contains('Gift') ||
      widget.offer.raw['serviceType'] == 'gift' ||
      widget.offer.raw['isGift'] == true;
  bool get _pinRequired =>
      _vanguard ||
      _healthPlus ||
      widget.offer.raw['pinRequired'] == true ||
      widget.offer.raw['receiverPinRequired'] == true;
  bool get _photoRequired =>
      _gift ||
      widget.offer.raw['photoRequired'] == true ||
      widget.offer.raw['proofPhotoRequired'] == true;
  bool get _signatureRequired =>
      widget.offer.raw['signatureRequired'] == true ||
      widget.offer.raw['receiverSignatureRequired'] == true;
  bool get _verificationRequired =>
      _vanguard ||
      _healthPlus ||
      _gift ||
      widget.offer.raw['verificationRequired'] == true ||
      widget.offer.raw['requiresVerification'] == true;

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
        _stage == RiderDeliveryStage.navigatingToPickup) {
      unawaited(_autoArrival(RiderDeliveryStage.arrivedAtPickup));
    }
    if (phase == RiderTrackingArrivalPhase.dropoff &&
        _stage == RiderDeliveryStage.navigatingToDropoff) {
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
    final action = _actionForStage(_stage);
    if (action == null) return;
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
        (action == 'verify_receiver_pin' && _pinRequired)) {
      evidence = await _captureEvidence(
        pickup: action == 'verify_collection_pin',
      );
      if (evidence == null) return;
    }
    final controller = widget.deliveryController;
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
      if (action == 'start_heading_to_pickup') {
        unawaited(_openNavigationOptions(toPickup: true));
      }
      if (action == 'start_delivery') {
        unawaited(_openNavigationOptions(toPickup: false));
      }
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
                  'vehicle_breakdown': 'Vehicle breakdown',
                  'accident': 'Accident',
                  'road_closure': 'Road closure',
                  'medical_emergency': 'Medical emergency',
                  'customer_change_request': 'Customer requests change',
                  'sender_unavailable': 'Sender unavailable',
                  'recipient_unavailable': 'Recipient unavailable',
                  'access_problem': 'Unable to access property',
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

  String? _actionForStage(RiderDeliveryStage current) {
    switch (current) {
      case RiderDeliveryStage.accepted:
        return 'start_heading_to_pickup';
      case RiderDeliveryStage.navigatingToPickup:
        return 'arrived_at_pickup';
      case RiderDeliveryStage.arrivedAtPickup:
        return _verificationRequired
            ? 'verify_collection_pin'
            : 'confirm_collected';
      case RiderDeliveryStage.pickupVerification:
        return 'verify_collection_pin';
      case RiderDeliveryStage.pickupVerified:
        return 'confirm_collected';
      case RiderDeliveryStage.collected:
        return 'start_delivery';
      case RiderDeliveryStage.navigatingToDropoff:
        return 'arrived_at_dropoff';
      case RiderDeliveryStage.arrivedAtDropoff:
      case RiderDeliveryStage.waiting:
        return _pinRequired ? 'verify_receiver_pin' : 'verify_receiver_pin';
      case RiderDeliveryStage.pinRequired:
        return 'verify_receiver_pin';
      case RiderDeliveryStage.issueReported:
      case RiderDeliveryStage.delivered:
        return null;
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

  Future<void> _openNavigationOptions({required bool toPickup}) async {
    final target = toPickup
        ? _locationPayload(
            widget.offer.raw['pickupDetails'] ?? widget.offer.raw['pickup'])
        : _locationPayload(
            widget.offer.raw['dropoffDetails'] ?? widget.offer.raw['dropoff']);
    final label = Uri.encodeComponent(
        toPickup ? widget.offer.pickupAddress : widget.offer.dropoffAddress);
    final lat = target.$1;
    final lng = target.$2;
    final query = lat != null && lng != null ? '$lat,$lng' : label;
    if (!mounted) return;
    final app = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: RiderGlassSurface(
            padding: const EdgeInsets.all(16),
            radius: 24,
            opacity: .78,
            blur: 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Navigate',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 10),
                _MapChoice(
                    label: 'Google Maps',
                    icon: Icons.map_rounded,
                    value: 'google'),
                _MapChoice(
                    label: 'Apple Maps',
                    icon: Icons.navigation_rounded,
                    value: 'apple'),
                _MapChoice(
                    label: 'Waze',
                    icon: Icons.alt_route_rounded,
                    value: 'waze'),
              ],
            ),
          ),
        ),
      ),
    );
    if (app == null) return;
    final uri = switch (app) {
      'google' =>
        Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$query'),
      'apple' => Uri.parse('https://maps.apple.com/?daddr=$query'),
      'waze' => Uri.parse('https://waze.com/ul?q=$query&navigate=yes'),
      _ => null,
    };
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  (double?, double?) _locationPayload(Object? value) {
    if (value is! Map) return (null, null);
    final data = Map<String, dynamic>.from(value);
    final lat = data['lat'] ?? data['latitude'];
    final lng = data['lng'] ?? data['longitude'];
    return (
      lat is num ? lat.toDouble() : null,
      lng is num ? lng.toDouble() : null
    );
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
        if (terminal == 'cancelled' ||
            terminal == 'failed' ||
            terminal.contains('no_show') ||
            terminal == 'disputed') {
          return _StateScaffold(
              title: terminal.replaceAll('_', ' '),
              message:
                  'This delivery can no longer progress. The latest backend state has been restored.');
        }
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
    final action = target == RiderDeliveryStage.arrivedAtDropoff
        ? 'arrived_at_dropoff'
        : 'arrived_at_pickup';
    setState(() {
      _arrivalTransitioning = true;
      _transitionError = null;
    });
    try {
      final result =
          await (widget.deliveryController ?? CallableRiderDeliveryController())
              .transition(
        deliveryId: widget.offer.id,
        action: action,
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
          onNavigateTab: widget.onNavigateTab,
          onReportIssue: _reportIssue);
    final nextTitle = _nextActionTitle(_stage);
    final irisConfirmed = _irisConfirmed(live);
    final differenceReported =
        live['loadDiscrepancy'] != null || live['adjustmentId'] != null;
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
                    status: _connectionStatus(_trackingSnapshot.status),
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
                    verificationRequired: _verificationRequired,
                    pinRequired: _pinRequired,
                    photoRequired: _photoRequired,
                    signatureRequired: _signatureRequired,
                    healthPlus: _healthPlus,
                    gift: _gift,
                    irisConfirmed: irisConfirmed,
                    irisConfirmationPending: _confirmingIris,
                    cta: _transitioning ? 'Updating...' : nextTitle,
                    onToggle: () => setState(() => _expanded = !_expanded),
                    onIssue: _transitioning ? null : _reportIssue,
                    onCustomerResponded: _transitioning
                        ? null
                        : () => _customerResponded(widget.offer.id),
                    onReportDifference:
                        _transitioning || irisConfirmed || differenceReported
                            ? null
                            : _reportIssue,
                    onConfirmIris: irisConfirmed ||
                            differenceReported ||
                            _confirmingIris ||
                            !_canConfirmIrisAtPickup(live)
                        ? null
                        : _confirmIrisAssessment,
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

  Future<void> _confirmIrisAssessment() async {
    if (_confirmingIris || _irisConfirmedFromBackend) return;
    setState(() {
      _confirmingIris = true;
      _transitionError = null;
    });
    try {
      final result =
          await (widget.deliveryController ?? CallableRiderDeliveryController())
              .confirmIrisAssessment(deliveryId: widget.offer.id);
      final acknowledgement = result['acknowledgement'] is Map
          ? Map<String, dynamic>.from(result['acknowledgement'] as Map)
          : const <String, dynamic>{};
      if (result['success'] == true &&
          acknowledgement['acknowledgementStatus'] == 'confirmed' &&
          mounted) {
        setState(() => _irisConfirmedFromBackend = true);
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(() => _transitionError =
            error.message ?? 'IRIS confirmation failed. Retry.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _transitionError =
            'IRIS confirmation failed. Check your connection and retry.');
      }
    } finally {
      if (mounted) setState(() => _confirmingIris = false);
    }
  }

  bool _irisConfirmed(Map<String, dynamic> live) {
    if (_irisConfirmedFromBackend) return true;
    final acknowledgement = live['riderIrisAcknowledgement'];
    if (acknowledgement is! Map) return false;
    final data = Map<String, dynamic>.from(acknowledgement);
    return data['acknowledgementStatus'] == 'confirmed' &&
        '${data['riderId'] ?? ''}' == widget.riderId;
  }

  bool _canConfirmIrisAtPickup(Map<String, dynamic> live) {
    if (_stage != RiderDeliveryStage.waiting) {
      return _stage == RiderDeliveryStage.arrivedAtPickup ||
          _stage == RiderDeliveryStage.pickupVerification ||
          _stage == RiderDeliveryStage.pickupVerified;
    }
    final waiting = live['waiting'];
    final phase = waiting is Map ? '${waiting['phase'] ?? ''}' : '';
    return phase != 'dropoff';
  }

  Future<void> _customerResponded(String deliveryId) async {
    setState(() {
      _transitioning = true;
      _transitionError = null;
    });
    try {
      await (widget.deliveryController ?? CallableRiderDeliveryController())
          .reportWaitingContext(
        deliveryId: deliveryId,
        type: 'customer_responded',
        note: 'Customer responded during waiting period',
      );
    } catch (_) {
      if (mounted) {
        setState(() =>
            _transitionError = 'Could not update waiting context. Retry.');
      }
    } finally {
      if (mounted) setState(() => _transitioning = false);
    }
  }

  String _connectionStatus(RiderLiveTrackingStatus status) {
    return switch (status) {
      RiderLiveTrackingStatus.live ||
      RiderLiveTrackingStatus.backgroundActive ||
      RiderLiveTrackingStatus.arrivedAtPickup ||
      RiderLiveTrackingStatus.arrivedAtDropoff =>
        'Live',
      RiderLiveTrackingStatus.offline => 'Offline',
      _ => 'Syncing',
    };
  }

  String _nextActionTitle(RiderDeliveryStage stage) {
    switch (stage) {
      case RiderDeliveryStage.accepted:
        return 'Navigate to Pickup';
      case RiderDeliveryStage.navigatingToPickup:
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
      required this.onNavigateTab,
      required this.onReportIssue});
  final RiderJobOffer offer;
  final Map<String, dynamic> delivery;
  final ValueChanged<int>? onNavigateTab;
  final VoidCallback? onReportIssue;

  @override
  Widget build(BuildContext context) {
    num value(String key) => delivery[key] is num ? delivery[key] as num : 0;
    final total = value('riderEarning');
    final breakdown = delivery['riderEarningBreakdown'] is Map
        ? Map<String, dynamic>.from(delivery['riderEarningBreakdown'] as Map)
        : const <String, dynamic>{};
    num part(String key) => breakdown[key] is num ? breakdown[key] as num : 0;
    final feedback = delivery['feedbackRequired'] == true ||
        delivery['requiresFeedback'] == true ||
        delivery['senderRatingRequired'] == true ||
        delivery['deliveryIssuePromptRequired'] == true;
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
                            const Text(
                                'Roth is separate from withdrawable cash.',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 11)),
                            const SizedBox(height: 20),
                            if (feedback) ...[
                              SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          content: Text(
                                              'Sender rating is not available for this delivery yet.'),
                                        ));
                                      },
                                      child: const Text('Rate Sender'))),
                              TextButton(
                                  onPressed: onReportIssue,
                                  child: const Text('Report Delivery Issue')),
                              const SizedBox(height: 4),
                            ],
                            SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                    onPressed: () {
                                      onNavigateTab?.call(0);
                                      Navigator.of(context).pop();
                                    },
                                    child: Text(feedback
                                        ? 'Return to Home'
                                        : 'Return Home'))),
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

class _WaitingPolicyCard extends StatefulWidget {
  final FirebaseFirestore firestore;
  final String deliveryId;
  final RiderDeliveryController controller;

  const _WaitingPolicyCard({
    required this.firestore,
    required this.deliveryId,
    required this.controller,
  });

  @override
  State<_WaitingPolicyCard> createState() => _WaitingPolicyCardState();
}

class _WaitingPolicyCardState extends State<_WaitingPolicyCard> {
  bool _updatingContext = false;
  bool _markingNoShow = false;
  String? _error;
  Map<String, dynamic>? _lastNoShowResult;

  Future<void> _customerResponded() async {
    setState(() {
      _updatingContext = true;
      _error = null;
    });
    try {
      await widget.controller.reportWaitingContext(
        deliveryId: widget.deliveryId,
        type: 'customer_responded',
        note: 'Customer responded during waiting period',
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not update waiting context.');
    } finally {
      if (mounted) setState(() => _updatingContext = false);
    }
  }

  Future<void> _markNoShow() async {
    setState(() {
      _markingNoShow = true;
      _error = null;
    });
    try {
      final result =
          await widget.controller.markNoShow(deliveryId: widget.deliveryId);
      if (mounted) setState(() => _lastNoShowResult = result);
    } catch (_) {
      if (mounted) setState(() => _error = 'No-show failed. Retry.');
    } finally {
      if (mounted) setState(() => _markingNoShow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.firestore
          .collection('deliveryRequests')
          .doc(widget.deliveryId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final waiting = data['waiting'] is Map
            ? Map<String, dynamic>.from(data['waiting'] as Map)
            : const <String, dynamic>{};
        final noShowFinancial = data['noShowFinancial'] is Map
            ? Map<String, dynamic>.from(data['noShowFinancial'] as Map)
            : _lastNoShowResult?['financial'] is Map
                ? Map<String, dynamic>.from(
                    _lastNoShowResult!['financial'] as Map)
                : const <String, dynamic>{};
        final rawDeadline = waiting['noShowAvailableAt'];
        final deadline = rawDeadline is Timestamp
            ? rawDeadline.toDate()
            : rawDeadline is num
                ? DateTime.fromMillisecondsSinceEpoch(rawDeadline.toInt())
                : null;
        final feeAmount = _moneyValue(
            noShowFinancial['amount'] ?? waiting['noShowFeeAmount']);
        final riderCompensation = _moneyValue(
            noShowFinancial['riderCompensation'] ??
                waiting['noShowRiderCompensation']);
        final currency =
            '${noShowFinancial['currency'] ?? waiting['currency'] ?? 'GBP'}';
        final noShowRecorded = data['state'] == 'sender_no_show_pickup' ||
            noShowFinancial.isNotEmpty ||
            _lastNoShowResult?['success'] == true;
        final backendHasWaitingDeadline = deadline != null;
        return StreamBuilder<int>(
          stream: Stream<int>.periodic(
              const Duration(seconds: 1), (value) => value),
          builder: (context, _) {
            final remaining = deadline == null
                ? const Duration(minutes: 3)
                : deadline.difference(DateTime.now());
            final seconds = remaining.isNegative ? 0 : remaining.inSeconds;
            final label =
                '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
            return RiderGlassSurface(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              radius: 18,
              opacity: .64,
              blur: 18,
              borderColor: Colors.white.withValues(alpha: .16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: _WaitingCountdownRing(
                      label: label,
                      noShowReady: false,
                      noShowRecorded: noShowRecorded,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Sender notified on arrival',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontFamily: RiderTypography.mono,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8)),
                  const SizedBox(height: 4),
                  Text(
                    'Waiting timer is server-side - this screen mirrors the backend clock and won\'t drift if you background the app.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600),
                  ),
                  if (feeAmount != null) ...[
                    const SizedBox(height: 10),
                    _WaitingChargeLine(
                      label: noShowRecorded
                          ? 'No-show charge recorded'
                          : 'No-show charge set by Circum policy',
                      amount: feeAmount,
                      currency: currency,
                    ),
                    if (riderCompensation != null)
                      _WaitingChargeLine(
                        label: noShowRecorded
                            ? 'Rider compensation recorded'
                            : 'Rider compensation if backend approves',
                        amount: riderCompensation,
                        currency: currency,
                        muted: !noShowRecorded,
                      ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: const TextStyle(
                            color: Color(0xFFFF8A8A),
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _WaitingActionButton(
                          label: 'Contact sender',
                          icon: Icons.chat_bubble_outline_rounded,
                          onTap: () => widget.controller.reportWaitingContext(
                            deliveryId: widget.deliveryId,
                            type: 'waiting_for_building_access',
                            note: 'Rider contacted sender during wait',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _WaitingActionButton(
                          label: _updatingContext
                              ? 'Updating...'
                              : 'Customer Responded',
                          icon: Icons.mark_chat_read_outlined,
                          onTap: _updatingContext ? null : _customerResponded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _WaitingNoShowButton(
                    label: noShowRecorded
                        ? 'No Show recorded'
                        : backendHasWaitingDeadline
                            ? _markingNoShow
                                ? 'Marking No Show...'
                                : 'Request No Show review'
                            : 'Waiting for no-show policy',
                    enabled: backendHasWaitingDeadline &&
                        !noShowRecorded &&
                        !_markingNoShow,
                    onTap: _markNoShow,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  double? _moneyValue(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class _WaitingCountdownRing extends StatelessWidget {
  const _WaitingCountdownRing({
    required this.label,
    required this.noShowReady,
    required this.noShowRecorded,
  });

  final String label;
  final bool noShowReady;
  final bool noShowRecorded;

  @override
  Widget build(BuildContext context) {
    final color = noShowRecorded
        ? const Color(0xFF34D399)
        : noShowReady
            ? const Color(0xFFFF452B)
            : const Color(0xFF3B82F6);
    return Container(
      width: 152,
      height: 152,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            color,
            color,
            Colors.white.withValues(alpha: .08),
            Colors.white.withValues(alpha: .08),
          ],
          stops: const [0, .72, .72, 1],
        ),
      ),
      child: Center(
        child: Container(
          width: 128,
          height: 128,
          decoration: const BoxDecoration(
            color: Color(0xFF07090F),
            shape: BoxShape.circle,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                noShowRecorded
                    ? 'DONE'
                    : noShowReady
                        ? '00:00'
                        : label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 31,
                    fontFamily: RiderTypography.mono,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                noShowRecorded
                    ? 'backend recorded'
                    : noShowReady
                        ? 'no-show available'
                        : 'free wait remaining',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .52),
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitingChargeLine extends StatelessWidget {
  const _WaitingChargeLine({
    required this.label,
    required this.amount,
    required this.currency,
    this.muted = false,
  });

  final String label;
  final double amount;
  final String currency;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final symbol = currency.toUpperCase() == 'GBP' ? '£' : '$currency ';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: muted ? .48 : .72),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          Text('$symbol${amount.toStringAsFixed(2)}',
              style: TextStyle(
                  color: muted
                      ? Colors.white.withValues(alpha: .50)
                      : Colors.white,
                  fontSize: 13,
                  fontFamily: RiderTypography.mono,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _WaitingActionButton extends StatelessWidget {
  const _WaitingActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF60A5FA), size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingNoShowButton extends StatelessWidget {
  const _WaitingNoShowButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedOpacity(
        opacity: enabled ? 1 : .46,
        duration: const Duration(milliseconds: 180),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFFF452B).withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFFF452B).withValues(alpha: .30)),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFFFF7A63),
                  fontSize: 12,
                  fontWeight: FontWeight.w900)),
        ),
      ),
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
      case RiderDeliveryStage.arrivedAtPickup:
        return 1;
      case RiderDeliveryStage.pickupVerification:
      case RiderDeliveryStage.pickupVerified:
        return 2;
      case RiderDeliveryStage.collected:
        return 3;
      case RiderDeliveryStage.navigatingToDropoff:
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
  final String status;

  const _NavigationInstructionCard(
      {required this.title, required this.subtitle, required this.status});

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
          const SizedBox(width: 8),
          _ConnectionPill(status: status),
        ],
      ),
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Live' => const Color(0xFF34D399),
      'Offline' => const Color(0xFFFF452B),
      _ => const Color(0xFFE0A93A),
    };
    return Semantics(
      label: 'Connection status $status',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontFamily: RiderTypography.mono,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MapChoice extends StatelessWidget {
  const _MapChoice({
    required this.label,
    required this.icon,
    required this.value,
  });

  final String label;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minLeadingWidth: 28,
      leading: Icon(icon, color: const Color(0xFF60A5FA)),
      title: Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
      onTap: () => Navigator.pop(context, value),
    );
  }
}

class _AcceptedBottomPanel extends StatelessWidget {
  final RiderJobOffer offer;
  final String riderRank;
  final RiderDeliveryStage stage;
  final bool expanded;
  final bool vanguard;
  final bool verificationRequired;
  final bool pinRequired;
  final bool photoRequired;
  final bool signatureRequired;
  final bool healthPlus;
  final bool gift;
  final bool irisConfirmed;
  final bool irisConfirmationPending;
  final String cta;
  final VoidCallback onToggle;
  final VoidCallback? onPrimary;
  final VoidCallback? onIssue;
  final VoidCallback? onCustomerResponded;
  final VoidCallback? onReportDifference;
  final VoidCallback? onConfirmIris;

  const _AcceptedBottomPanel({
    required this.offer,
    required this.riderRank,
    required this.stage,
    required this.expanded,
    required this.vanguard,
    required this.verificationRequired,
    required this.pinRequired,
    required this.photoRequired,
    required this.signatureRequired,
    required this.healthPlus,
    required this.gift,
    required this.irisConfirmed,
    required this.irisConfirmationPending,
    required this.cta,
    required this.onToggle,
    required this.onPrimary,
    required this.onIssue,
    required this.onCustomerResponded,
    required this.onReportDifference,
    required this.onConfirmIris,
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
                        _ExpandedLine(
                            title: 'Pickup', body: offer.pickupAddress),
                        _ExpandedLine(
                            title: 'Drop-off', body: offer.dropoffAddress),
                        _ExpandedLine(
                          title: 'IRIS Brief',
                          body:
                              '${offer.parcelGuidance}\nVehicle: ${offer.minimumVehicle} - Weight: ${offer.weightText}',
                        ),
                        _PickupWorkflowPanel(
                          vanguard: vanguard,
                          verificationRequired: verificationRequired,
                          offer: offer,
                          irisConfirmed: irisConfirmed,
                          irisConfirmationPending: irisConfirmationPending,
                          onConfirmIris: onConfirmIris,
                          onReportDifference: onReportDifference,
                        ),
                        const SizedBox(height: 10),
                        _ExpandedLine(
                          title: 'Verification',
                          body: _verificationCopy,
                        ),
                        _StageTracker(
                            stage: stage,
                            verificationRequired: verificationRequired),
                        if (stage == RiderDeliveryStage.arrivedAtPickup ||
                            stage == RiderDeliveryStage.waiting) ...[
                          const SizedBox(height: 10),
                          _SecondaryButton(
                            icon: Icons.mark_chat_read_outlined,
                            label: 'Customer Responded',
                            onTap: onCustomerResponded ?? () {},
                          ),
                        ],
                        const SizedBox(height: 10),
                        _SecondaryContactRow(offer: offer, vanguard: vanguard),
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

  String get _verificationCopy {
    final methods = <String>[];
    if (pinRequired) methods.add('PIN mandatory');
    if (photoRequired) methods.add('photo required');
    if (signatureRequired) methods.add('signature required');
    if (methods.isEmpty) methods.add('photo optional');
    final service = healthPlus
        ? 'Health+'
        : vanguard
            ? 'Vanguard'
            : gift
                ? 'Gift'
                : 'Standard';
    return '$service verification: ${methods.join(', ')}. Requirements are read from backend state.';
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
  final RiderJobOffer offer;
  final bool irisConfirmed;
  final bool irisConfirmationPending;
  final VoidCallback? onConfirmIris;
  final VoidCallback? onReportDifference;

  const _PickupWorkflowPanel({
    required this.vanguard,
    required this.verificationRequired,
    required this.offer,
    required this.irisConfirmed,
    required this.irisConfirmationPending,
    required this.onConfirmIris,
    required this.onReportDifference,
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
    final iris = _irisRecommendation(offer);
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
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: .10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF60A5FA).withValues(alpha: .22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('IRIS Recommendation',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                _IrisLine('Detected Item', iris.detectedItem),
                _IrisLine('Suggested Category', iris.category),
                _IrisLine('Suggested Weight Band', iris.weightBand),
                _IrisLine('Confidence', iris.confidence),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MiniGlassButton(
                        label: irisConfirmed
                            ? 'Confirmed'
                            : irisConfirmationPending
                                ? 'Confirming...'
                                : 'Confirm',
                        icon: irisConfirmed
                            ? Icons.verified_rounded
                            : Icons.check_rounded,
                        onTap: irisConfirmed ? null : onConfirmIris,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniGlassButton(
                        label: 'Report Difference',
                        icon: Icons.report_outlined,
                        onTap: irisConfirmed ? null : onReportDifference,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static _IrisRecommendation _irisRecommendation(RiderJobOffer offer) {
    final raw = offer.raw;
    final iris = raw['irisRecommendation'] is Map
        ? Map<String, dynamic>.from(raw['irisRecommendation'] as Map)
        : raw['iris'] is Map
            ? Map<String, dynamic>.from(raw['iris'] as Map)
            : const <String, dynamic>{};
    return _IrisRecommendation(
      detectedItem:
          '${iris['detectedItem'] ?? raw['itemName'] ?? offer.parcelGuidance}',
      category:
          '${iris['suggestedCategory'] ?? raw['suggestedCategory'] ?? offer.points.label}',
      weightBand:
          '${iris['weightBand'] ?? iris['suggestedWeightBand'] ?? raw['weightBand'] ?? offer.weightText}',
      confidence:
          '${iris['confidence'] ?? raw['irisConfidence'] ?? 'Awaiting parcel check'}',
    );
  }
}

class _IrisRecommendation {
  const _IrisRecommendation({
    required this.detectedItem,
    required this.category,
    required this.weightBand,
    required this.confidence,
  });

  final String detectedItem;
  final String category;
  final String weightBand;
  final String confidence;
}

class _IrisLine extends StatelessWidget {
  const _IrisLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .50),
                    fontSize: 10,
                    fontFamily: RiderTypography.mono,
                    fontWeight: FontWeight.w800)),
          ),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _MiniGlassButton extends StatelessWidget {
  const _MiniGlassButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .11)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF60A5FA), size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900)),
            ),
          ],
        ),
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
        return 'Navigate to Pickup';
      case RiderDeliveryStage.arrivedAtPickup:
        return 'I\'ve Arrived';
      case RiderDeliveryStage.pickupVerification:
      case RiderDeliveryStage.pickupVerified:
        return 'Verify Parcel';
      case RiderDeliveryStage.collected:
        return 'Collected Parcel';
      case RiderDeliveryStage.navigatingToDropoff:
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
  final bool vanguard;

  const _SecondaryContactRow({required this.offer, required this.vanguard});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _SecondaryButton(
                icon: Icons.call_rounded,
                label: 'Call',
                onTap: () => _call(offer.raw))),
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
      ],
    );
  }

  Future<void> _call(Map<String, dynamic> raw) async {
    final number = '${raw['senderPhone'] ?? raw['contactPhone'] ?? ''}'
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
