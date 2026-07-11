// ignore_for_file: deprecated_member_use, prefer_const_constructors, curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../home/view/ride_chats.dart';
import '../home/bloc/home_bloc.dart';
import '../founder_access/founder_rider_access.dart';
import '../rider_truth/rider_truth.dart';
import '../support/view/support.dart';
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

    final home = context.watch<HomeBloc>().state;
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
                  final riderData = <String, dynamic>{
                    ...?profileSnapshot.data?.data(),
                    ...?riderSnapshot.data?.data()
                  };
                  final rider =
                      _riderProfile(user.uid, riderData, founder: founder);

                  if (!rider.canAcceptJobs)
                    return _StateScaffold(
                        title: 'Account action required',
                        message: rider.blockedReason ??
                            'Your Rider account cannot receive jobs right now.');
                  if (home.rideStatus == RideStatus.offline)
                    return _StateScaffold(
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
                        return const _StateScaffold(
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
                        return const _StateScaffold(
                          title: 'Loading offers',
                          message: 'Checking nearby delivery requests.',
                          loading: true,
                        );
                      }

                      final offers = _filterOffers(
                        docs: snapshot.data!.docs,
                        riderId: user.uid,
                        riderVehicle: rider.riderVehicle,
                        founder: founder,
                      );

                      if (_activeIndex >= offers.length && offers.isNotEmpty) {
                        scheduleMicrotask(() {
                          if (mounted)
                            setState(() => _activeIndex = offers.length - 1);
                        });
                      }

                      if (offers.isEmpty) {
                        return const _StateScaffold(
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
      {bool founder = false}) {
    final canAccept = founder || RiderOnboardingPolicy.canAcceptJobs(riderData);
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
    bool founder = false,
  }) {
    return docs
        .where((doc) => _isVisibleToRider(doc.data(), riderId, riderVehicle,
            founder: founder))
        .map((doc) =>
            RiderJobOffer.fromFirestore(docId: doc.id, data: doc.data()))
        .toList();
  }

  bool _isVisibleToRider(
      Map<String, dynamic> data, String riderId, String? riderVehicle,
      {bool founder = false}) {
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
    return founder ||
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
                  const Color(0xFF07090F).withOpacity(0.22),
                  const Color(0xFF07090F).withOpacity(0.72),
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
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D111C),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(.09)),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF87171).withOpacity(.12),
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
                            color: Colors.white.withOpacity(.62), height: 1.4)),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1020).withOpacity(0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Text(
            '$count Available Offers',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Spacer(),
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
                color: Colors.white.withOpacity(0.58),
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

  const _OfferMapBackground({required this.offer, this.focusPickup = false});

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
      },
      polylines: {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [pickup, dropoff],
          color: const Color(0xFF60A5FA),
          width: 5,
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
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x + 80, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += 52) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 24), gridPaint);
    }

    final routePaint = Paint()
      ..color = const Color(0xFF60A5FA).withOpacity(0.72)
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020).withOpacity(0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF60A5FA).withOpacity(0.26)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: Colors.white.withOpacity(0.86),
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
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateScaffold({
    required this.title,
    required this.message,
    this.loading = false,
    this.actionLabel,
    this.onAction,
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
                if (actionLabel != null) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                      width: 220,
                      child: FilledButton(
                          onPressed: onAction, child: Text(actionLabel!))),
                ],
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.68),
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
  static const ordered = [
    RiderDeliveryStage.accepted,
    RiderDeliveryStage.navigatingToPickup,
    RiderDeliveryStage.arrivedAtPickup,
    RiderDeliveryStage.pickupVerification,
    RiderDeliveryStage.pickupVerified,
    RiderDeliveryStage.collected,
    RiderDeliveryStage.navigatingToDropoff,
    RiderDeliveryStage.arrivedAtDropoff,
    RiderDeliveryStage.waiting,
    RiderDeliveryStage.pinRequired,
    RiderDeliveryStage.delivered,
  ];

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

  static RiderDeliveryStage? nextStage(
    RiderDeliveryStage current, {
    required bool verificationRequired,
    required bool pinRequired,
  }) {
    switch (current) {
      case RiderDeliveryStage.accepted:
        return RiderDeliveryStage.navigatingToPickup;
      case RiderDeliveryStage.navigatingToPickup:
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
  bool _expanded = false;
  bool _transitioning = false;
  String? _transitionError;

  bool get _vanguard =>
      widget.offer.warningChips.contains('Vanguard') ||
      widget.offer.raw['requiresVanguard'] == true;
  bool get _pinRequired => _vanguard || widget.offer.raw['pinRequired'] == true;
  bool get _verificationRequired =>
      _vanguard ||
      widget.offer.raw['verificationRequired'] == true ||
      widget.offer.raw['requiresVerification'] == true;

  @override
  void initState() {
    super.initState();
    _stage =
        RiderDeliveryStagePolicy.fromRaw(widget.offer.raw['deliveryStage']);
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
        (action == 'verify_receiver_pin' && _pinRequired)) {
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
      case RiderDeliveryStage.arrivedAtPickup:
        return 'arrived_at_pickup';
      case RiderDeliveryStage.pickupVerification:
      case RiderDeliveryStage.pickupVerified:
      case RiderDeliveryStage.collected:
        return 'verify_collection_pin';
      case RiderDeliveryStage.navigatingToDropoff:
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
        return _buildExperience(context, live);
      },
    );
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
          _OfferMapBackground(offer: widget.offer),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF07090F).withOpacity(0.10),
                  const Color(0xFF07090F).withOpacity(0.34),
                  const Color(0xFF07090F).withOpacity(0.78),
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
    return Scaffold(
        backgroundColor: const Color(0xFF07090F),
        body: Stack(children: [
          _OfferMapBackground(offer: offer),
          Container(color: const Color(0xFF07090F).withOpacity(.78)),
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
                                    color: Colors.white.withOpacity(.62),
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
                    color: Colors.white.withOpacity(.7),
                    fontWeight: strong ? FontWeight.w800 : FontWeight.w500))),
        Text('£${amount.toStringAsFixed(2)}',
            style: TextStyle(
                color: Colors.white,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700))
      ]));
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
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1020).withOpacity(0.9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
              ),
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
                          style:
                              TextStyle(color: Colors.white.withOpacity(0.7)),
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
        color: const Color(0xFF0B1020).withOpacity(0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
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
                        : Colors.white.withOpacity(0.08),
                    border: Border.all(
                      color: complete || active
                          ? const Color(0xFF60A5FA)
                          : Colors.white.withOpacity(0.10),
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
                    color:
                        active ? Colors.white : Colors.white.withOpacity(0.52),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1020).withOpacity(0.78),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF60A5FA).withOpacity(0.25)),
        ),
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

class _NavigationInstructionCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _NavigationInstructionCard(
      {required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020).withOpacity(0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF60A5FA).withOpacity(0.26)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.22),
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
                        color: Colors.white.withOpacity(0.68),
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
    required this.verificationRequired,
    required this.cta,
    required this.onToggle,
    required this.onPrimary,
    required this.onIssue,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(maxHeight: expanded ? 560 : 330),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020).withOpacity(0.84),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.18),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
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
                    color: Colors.white.withOpacity(0.22),
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
                    _ExpandedLine(title: 'Pickup', body: offer.pickupAddress),
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
                color: Colors.white.withOpacity(0.72),
                fontSize: 13,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 11),
        Text(_collapsedChips(offer),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Colors.white.withOpacity(0.72),
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
                color: Colors.white.withOpacity(0.76),
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Vehicle: ${offer.minimumVehicle} - Pickup: ${offer.pickupTiming}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Colors.white.withOpacity(0.62),
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
        color: const Color(0xFF2563EB).withOpacity(0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF60A5FA).withOpacity(0.26)),
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
                  color: Colors.white.withOpacity(0.72),
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
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                        color: Colors.white.withOpacity(0.72),
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
                ? const Color(0xFF3B82F6).withOpacity(0.25)
                : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: active
                    ? const Color(0xFF60A5FA).withOpacity(0.4)
                    : Colors.white.withOpacity(0.08)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: active ? Colors.white : Colors.white.withOpacity(0.58),
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
                          builder: (_) => const RideChatPageView()),
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
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
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
