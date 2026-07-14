import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum RiderLiveTrackingStatus {
  idle,
  acquiring,
  live,
  foregroundOnly,
  backgroundActive,
  permissionRequired,
  permissionDenied,
  permissionPermanentlyDenied,
  servicesDisabled,
  poorAccuracy,
  offline,
  reconnecting,
  arrivedAtPickup,
  arrivedAtDropoff,
  stopped,
  error,
}

extension RiderLiveTrackingStatusModel on RiderLiveTrackingStatus {
  String get internalValue => switch (this) {
        RiderLiveTrackingStatus.live => 'live',
        RiderLiveTrackingStatus.acquiring => 'acquiringLocation',
        RiderLiveTrackingStatus.poorAccuracy => 'poorGpsAccuracy',
        RiderLiveTrackingStatus.foregroundOnly => 'foregroundOnly',
        RiderLiveTrackingStatus.backgroundActive => 'backgroundTrackingActive',
        RiderLiveTrackingStatus.offline => 'offline',
        RiderLiveTrackingStatus.reconnecting => 'reconnecting',
        RiderLiveTrackingStatus.permissionRequired => 'permissionRequired',
        RiderLiveTrackingStatus.permissionDenied => 'permissionRequired',
        RiderLiveTrackingStatus.permissionPermanentlyDenied =>
          'permissionRequired',
        RiderLiveTrackingStatus.servicesDisabled => 'locationServicesDisabled',
        RiderLiveTrackingStatus.arrivedAtPickup => 'arrivedAtPickup',
        RiderLiveTrackingStatus.arrivedAtDropoff => 'arrivedAtDropoff',
        RiderLiveTrackingStatus.stopped => 'trackingStopped',
        RiderLiveTrackingStatus.idle => 'trackingStopped',
        RiderLiveTrackingStatus.error => 'reconnecting',
      };

  String get title => switch (this) {
        RiderLiveTrackingStatus.live => 'Live tracking',
        RiderLiveTrackingStatus.acquiring => 'Finding your location...',
        RiderLiveTrackingStatus.poorAccuracy => 'Weak GPS signal',
        RiderLiveTrackingStatus.foregroundOnly => 'Foreground tracking only',
        RiderLiveTrackingStatus.backgroundActive =>
          'Background tracking active',
        RiderLiveTrackingStatus.offline => 'Offline - waiting for connection',
        RiderLiveTrackingStatus.reconnecting => 'Reconnecting...',
        RiderLiveTrackingStatus.permissionRequired ||
        RiderLiveTrackingStatus.permissionDenied ||
        RiderLiveTrackingStatus.permissionPermanentlyDenied =>
          'Location permission required',
        RiderLiveTrackingStatus.servicesDisabled =>
          'Location services disabled',
        RiderLiveTrackingStatus.arrivedAtPickup => 'Arrived at pickup',
        RiderLiveTrackingStatus.arrivedAtDropoff => 'Arrived at drop-off',
        RiderLiveTrackingStatus.stopped ||
        RiderLiveTrackingStatus.idle =>
          'Tracking stopped',
        RiderLiveTrackingStatus.error => 'Tracking needs attention',
      };

  String get supportingText => switch (this) {
        RiderLiveTrackingStatus.live =>
          'Your location is updating for this delivery.',
        RiderLiveTrackingStatus.acquiring => 'Finding your location...',
        RiderLiveTrackingStatus.poorAccuracy =>
          'Continue tracking cautiously until signal improves.',
        RiderLiveTrackingStatus.foregroundOnly =>
          'Keep the app open so Circum can update this delivery.',
        RiderLiveTrackingStatus.backgroundActive =>
          'Background tracking active',
        RiderLiveTrackingStatus.offline => 'Offline - waiting for connection.',
        RiderLiveTrackingStatus.reconnecting => 'Reconnecting...',
        RiderLiveTrackingStatus.permissionRequired ||
        RiderLiveTrackingStatus.permissionDenied =>
          'Location is required while you have an active delivery.',
        RiderLiveTrackingStatus.permissionPermanentlyDenied =>
          'Open settings to allow delivery tracking.',
        RiderLiveTrackingStatus.servicesDisabled =>
          'Turn on device location services to continue tracking.',
        RiderLiveTrackingStatus.arrivedAtPickup =>
          'Pickup verification is now available.',
        RiderLiveTrackingStatus.arrivedAtDropoff =>
          'Drop-off verification is now available.',
        RiderLiveTrackingStatus.stopped ||
        RiderLiveTrackingStatus.idle =>
          'Live tracking has ended for this delivery.',
        RiderLiveTrackingStatus.error =>
          'Check your signal and retry tracking.',
      };

  String get accessibilityLabel => '$title. $supportingText';
}

enum RiderTrackingArrivalPhase { pickup, dropoff }

class RiderGeoPoint {
  const RiderGeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class RiderLiveTrackingSnapshot {
  const RiderLiveTrackingSnapshot({
    required this.status,
    this.position,
    this.message,
    this.arrivalPhase,
    this.lastPublishedAt,
    this.accuracyMeters,
    this.backgroundCapable = false,
    this.queueDepth = 0,
  });

  final RiderLiveTrackingStatus status;
  final Position? position;
  final String? message;
  final RiderTrackingArrivalPhase? arrivalPhase;
  final DateTime? lastPublishedAt;
  final double? accuracyMeters;
  final bool backgroundCapable;
  final int queueDepth;

  RiderLiveTrackingSnapshot copyWith({
    RiderLiveTrackingStatus? status,
    Position? position,
    String? message,
    RiderTrackingArrivalPhase? arrivalPhase,
    DateTime? lastPublishedAt,
    double? accuracyMeters,
    bool? backgroundCapable,
    int? queueDepth,
  }) {
    return RiderLiveTrackingSnapshot(
      status: status ?? this.status,
      position: position ?? this.position,
      message: message ?? this.message,
      arrivalPhase: arrivalPhase,
      lastPublishedAt: lastPublishedAt ?? this.lastPublishedAt,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      backgroundCapable: backgroundCapable ?? this.backgroundCapable,
      queueDepth: queueDepth ?? this.queueDepth,
    );
  }
}

class RiderLiveTrackingPolicy {
  static const defaultMinInterval = Duration(seconds: 10);
  static const defaultMaxInterval = Duration(seconds: 30);
  static const nearDestinationMinInterval = Duration(seconds: 5);
  static const minMoveMeters = 25.0;
  static const nearDestinationMoveMeters = 10.0;
  static const poorAccuracyMeters = 80.0;
  static const arrivalRadiusMeters = 70.0;
  static const impossibleJumpMetersPerSecond = 55.0;
  static const maxQueuedUpdates = 8;
  static const staleUpdateAfter = Duration(minutes: 3);

  static bool isActiveDeliveryStatus(dynamic value) {
    final status = '$value'.toLowerCase().trim();
    return {
      'accepted',
      'navigating_to_pickup',
      'travelling_to_pickup',
      'arrived_at_pickup',
      'waiting_at_pickup',
      'waiting',
      'pickup_verification',
      'pickup_verified',
      'collected',
      'in_transit',
      'navigating_to_dropoff',
      'travelling_to_dropoff',
      'arrived_at_dropoff',
      'pin_required',
      'awaiting_pin',
    }.contains(status);
  }

  static bool isTerminalDeliveryStatus(dynamic value) {
    final status = '$value'.toLowerCase().trim();
    return {
      'completed',
      'complete',
      'delivered',
      'cancelled',
      'canceled',
      'failed',
      'no_show',
      'disputed',
      'reassigned',
      'assignment_removed',
    }.contains(status);
  }

  static bool assignedToRider(Map<String, dynamic> delivery, String riderId) {
    final assigned = delivery['riderId'] ??
        delivery['driverId'] ??
        delivery['assignedRiderId'] ??
        delivery['assignedDriverId'];
    return '$assigned'.trim() == riderId;
  }

  static bool shouldPublish({
    required Position next,
    Position? previous,
    DateTime? lastPublishedAt,
    bool nearDestination = false,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    if (previous == null || lastPublishedAt == null) return true;
    final age = currentTime.difference(lastPublishedAt);
    final minInterval =
        nearDestination ? nearDestinationMinInterval : defaultMinInterval;
    if (age < minInterval) return false;
    final moved = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      next.latitude,
      next.longitude,
    );
    final moveThreshold =
        nearDestination ? nearDestinationMoveMeters : minMoveMeters;
    return moved >= moveThreshold || age >= defaultMaxInterval;
  }

  static bool isUsableAccuracy(Position position) {
    return position.accuracy <= poorAccuracyMeters;
  }

  static String signalQuality(Position position) {
    if (position.accuracy <= 25) return 'high';
    if (position.accuracy <= poorAccuracyMeters) return 'medium';
    return 'reduced';
  }

  static bool isStalePosition(Position position, {DateTime? now}) {
    final timestamp = position.timestamp;
    final current = now ?? DateTime.now();
    return current.difference(timestamp).abs() > staleUpdateAfter;
  }

  static bool isImpossibleJump({
    required Position previous,
    required Position next,
  }) {
    final elapsed =
        next.timestamp.difference(previous.timestamp).inMilliseconds.abs();
    if (elapsed == 0) return false;
    final distance = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      next.latitude,
      next.longitude,
    );
    final metersPerSecond = distance / (elapsed / 1000);
    return metersPerSecond > impossibleJumpMetersPerSecond &&
        next.accuracy > previous.accuracy;
  }

  static bool nearDestination(Position position, RiderGeoPoint destination) {
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      destination.latitude,
      destination.longitude,
    );
    return distance <= arrivalRadiusMeters + position.accuracy;
  }

  static bool shouldSignalArrival({
    required Queue<DateTime> hits,
    required DateTime now,
  }) {
    if (hits.length < 2) return false;
    return now.difference(hits.first) >= const Duration(seconds: 8);
  }
}

class RiderLiveTrackingController {
  RiderLiveTrackingController({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _states = StreamController<RiderLiveTrackingSnapshot>.broadcast();
  final Queue<_QueuedLocationUpdate> _queue = Queue<_QueuedLocationUpdate>();
  final Queue<DateTime> _pickupArrivalHits = Queue<DateTime>();
  final Queue<DateTime> _dropoffArrivalHits = Queue<DateTime>();

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _deliverySub;
  RiderLiveTrackingSnapshot _snapshot =
      const RiderLiveTrackingSnapshot(status: RiderLiveTrackingStatus.idle);
  String? _deliveryId;
  String? _riderId;
  String? _trackingStatus;
  RiderGeoPoint? _pickup;
  RiderGeoPoint? _dropoff;
  Position? _lastPublishedPosition;
  DateTime? _lastPublishedAt;
  bool _started = false;
  bool _stopping = false;
  bool _arrivalPickupSignalled = false;
  bool _arrivalDropoffSignalled = false;

  Stream<RiderLiveTrackingSnapshot> get states => _states.stream;
  RiderLiveTrackingSnapshot get snapshot => _snapshot;

  Future<void> start({
    required String deliveryId,
    required String riderId,
    required String trackingStatus,
    required RiderGeoPoint? pickup,
    required RiderGeoPoint? dropoff,
  }) async {
    if (_started &&
        _deliveryId == deliveryId &&
        _riderId == riderId &&
        _trackingStatus == trackingStatus) {
      return;
    }
    await stop(status: 'switching', publishStop: false);
    _started = true;
    _stopping = false;
    _deliveryId = deliveryId;
    _riderId = riderId;
    _trackingStatus = trackingStatus;
    _pickup = pickup;
    _dropoff = dropoff;
    _arrivalPickupSignalled = false;
    _arrivalDropoffSignalled = false;
    _emit(const RiderLiveTrackingSnapshot(
      status: RiderLiveTrackingStatus.acquiring,
      message: 'Acquiring location',
      backgroundCapable: !kIsWeb,
    ));

    final permissionState = await _ensurePermission();
    if (permissionState != null) {
      _emit(permissionState);
      return;
    }

    _deliverySub = _firestore
        .collection('deliveryRequests')
        .doc(deliveryId)
        .snapshots()
        .listen(_handleDeliverySnapshot, onError: (_) {
      _emit(_snapshot.copyWith(
        status: RiderLiveTrackingStatus.reconnecting,
        message: 'Reconnecting to delivery state',
      ));
    });

    const settings = kIsWeb
        ? LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          )
        : LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 8,
          );
    _positionSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(_handlePosition, onError: (Object error) {
      _emit(_snapshot.copyWith(
        status: RiderLiveTrackingStatus.error,
        message: 'GPS signal unavailable. Retry when your signal improves.',
      ));
    });
  }

  Future<void> stop({
    required String status,
    bool publishStop = true,
  }) async {
    if (_stopping) return;
    _stopping = true;
    final deliveryId = _deliveryId;
    final riderId = _riderId;
    await _positionSub?.cancel();
    await _deliverySub?.cancel();
    _positionSub = null;
    _deliverySub = null;
    _queue.clear();
    _pickupArrivalHits.clear();
    _dropoffArrivalHits.clear();
    _started = false;
    _deliveryId = null;
    _riderId = null;
    _trackingStatus = null;
    _pickup = null;
    _dropoff = null;
    _lastPublishedPosition = null;
    _lastPublishedAt = null;
    if (publishStop && deliveryId != null && riderId != null) {
      try {
        await _writeStop(
            deliveryId: deliveryId, riderId: riderId, status: status);
      } catch (_) {
        // Stop must never block sign-out or completion navigation.
      }
    }
    _emit(const RiderLiveTrackingSnapshot(
      status: RiderLiveTrackingStatus.stopped,
      message: 'Tracking stopped',
    ));
    _stopping = false;
  }

  Future<void> retry() async {
    final deliveryId = _deliveryId;
    final riderId = _riderId;
    final status = _trackingStatus;
    if (deliveryId == null || riderId == null || status == null) return;
    await start(
      deliveryId: deliveryId,
      riderId: riderId,
      trackingStatus: status,
      pickup: _pickup,
      dropoff: _dropoff,
    );
  }

  void dispose() {
    unawaited(stop(status: 'disposed'));
    unawaited(_states.close());
  }

  Future<RiderLiveTrackingSnapshot?> _ensurePermission() async {
    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) {
        return const RiderLiveTrackingSnapshot(
          status: RiderLiveTrackingStatus.servicesDisabled,
          message: 'Location services are disabled.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const RiderLiveTrackingSnapshot(
          status: RiderLiveTrackingStatus.permissionDenied,
          message: 'Location permission is required for active deliveries.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const RiderLiveTrackingSnapshot(
          status: RiderLiveTrackingStatus.permissionPermanentlyDenied,
          message: 'Open settings to allow delivery tracking.',
        );
      }
      if (kIsWeb || permission == LocationPermission.whileInUse) {
        return null;
      }
      return null;
    } catch (_) {
      return const RiderLiveTrackingSnapshot(
        status: RiderLiveTrackingStatus.permissionRequired,
        message: 'Location permission could not be checked.',
      );
    }
  }

  void _handleDeliverySnapshot(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final deliveryId = _deliveryId;
    final riderId = _riderId;
    if (deliveryId == null || riderId == null) return;
    final data = snapshot.data();
    if (data == null ||
        !RiderLiveTrackingPolicy.assignedToRider(data, riderId) ||
        RiderLiveTrackingPolicy.isTerminalDeliveryStatus(
          data['deliveryStage'] ?? data['deliveryStatus'] ?? data['status'],
        ) ||
        !RiderLiveTrackingPolicy.isActiveDeliveryStatus(
          data['deliveryStage'] ?? data['deliveryStatus'] ?? data['status'],
        )) {
      unawaited(stop(status: 'inactive_or_unassigned'));
      return;
    }
    _flushQueue();
  }

  void _handlePosition(Position position) {
    final deliveryId = _deliveryId;
    final riderId = _riderId;
    final status = _trackingStatus;
    if (deliveryId == null || riderId == null || status == null) return;
    final now = DateTime.now();
    if (RiderLiveTrackingPolicy.isStalePosition(position, now: now)) {
      _emit(_snapshot.copyWith(
        status: RiderLiveTrackingStatus.reconnecting,
        message: RiderLiveTrackingStatus.reconnecting.supportingText,
        queueDepth: _queue.length,
      ));
      return;
    }
    final previous = _lastPublishedPosition ?? _snapshot.position;
    if (previous != null &&
        RiderLiveTrackingPolicy.isImpossibleJump(
          previous: previous,
          next: position,
        )) {
      _emit(_snapshot.copyWith(
        status: RiderLiveTrackingStatus.poorAccuracy,
        position: previous,
        message: RiderLiveTrackingStatus.poorAccuracy.supportingText,
        accuracyMeters: position.accuracy,
        queueDepth: _queue.length,
      ));
      return;
    }
    final destination = _activeDestination(status);
    final nearDestination = destination != null &&
        RiderLiveTrackingPolicy.nearDestination(position, destination);
    final trackingStatus = _statusForPosition(position);
    _emit(_snapshot.copyWith(
      status: trackingStatus,
      position: position,
      message: trackingStatus.supportingText,
      accuracyMeters: position.accuracy,
      backgroundCapable: !kIsWeb,
      queueDepth: _queue.length,
    ));
    _recordArrivalHit(position, status, now);
    if (!RiderLiveTrackingPolicy.shouldPublish(
      next: position,
      previous: _lastPublishedPosition,
      lastPublishedAt: _lastPublishedAt,
      nearDestination: nearDestination,
      now: now,
    )) {
      return;
    }
    _publish(position, now);
  }

  RiderGeoPoint? _activeDestination(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('dropoff') ||
        normalized.contains('delivery') ||
        normalized.contains('transit') ||
        normalized.contains('pin')) {
      return _dropoff;
    }
    return _pickup;
  }

  RiderLiveTrackingStatus _statusForPosition(Position position) {
    if (!RiderLiveTrackingPolicy.isUsableAccuracy(position)) {
      return RiderLiveTrackingStatus.poorAccuracy;
    }
    if (kIsWeb) {
      return RiderLiveTrackingStatus.foregroundOnly;
    }
    return RiderLiveTrackingStatus.live;
  }

  void _recordArrivalHit(Position position, String status, DateTime now) {
    final normalized = status.toLowerCase();
    if (normalized.contains('pickup') && _pickup != null) {
      _recordPhaseHit(
        queue: _pickupArrivalHits,
        position: position,
        destination: _pickup!,
        now: now,
        phase: RiderTrackingArrivalPhase.pickup,
      );
    }
    if ((normalized.contains('dropoff') ||
            normalized.contains('delivery') ||
            normalized.contains('pin')) &&
        _dropoff != null) {
      _recordPhaseHit(
        queue: _dropoffArrivalHits,
        position: position,
        destination: _dropoff!,
        now: now,
        phase: RiderTrackingArrivalPhase.dropoff,
      );
    }
  }

  void _recordPhaseHit({
    required Queue<DateTime> queue,
    required Position position,
    required RiderGeoPoint destination,
    required DateTime now,
    required RiderTrackingArrivalPhase phase,
  }) {
    if (!RiderLiveTrackingPolicy.isUsableAccuracy(position) ||
        !RiderLiveTrackingPolicy.nearDestination(position, destination)) {
      queue.clear();
      return;
    }
    queue.addLast(now);
    while (queue.length > 3) {
      queue.removeFirst();
    }
    if (RiderLiveTrackingPolicy.shouldSignalArrival(hits: queue, now: now)) {
      if (phase == RiderTrackingArrivalPhase.pickup &&
          !_arrivalPickupSignalled) {
        _arrivalPickupSignalled = true;
        _emit(_snapshot.copyWith(
          status: RiderLiveTrackingStatus.arrivedAtPickup,
          arrivalPhase: phase,
          message: 'Arrived at pickup',
        ));
      }
      if (phase == RiderTrackingArrivalPhase.dropoff &&
          !_arrivalDropoffSignalled) {
        _arrivalDropoffSignalled = true;
        _emit(_snapshot.copyWith(
          status: RiderLiveTrackingStatus.arrivedAtDropoff,
          arrivalPhase: phase,
          message: 'Arrived at drop-off',
        ));
      }
    }
  }

  Future<void> _publish(Position position, DateTime now) async {
    final deliveryId = _deliveryId;
    final riderId = _riderId;
    final status = _trackingStatus;
    if (deliveryId == null || riderId == null || status == null) return;
    final update = _QueuedLocationUpdate(
      position: position,
      createdAt: now,
      trackingStatus: status,
    );
    try {
      await _writeUpdate(
        deliveryId: deliveryId,
        riderId: riderId,
        update: update,
      );
      _lastPublishedPosition = position;
      _lastPublishedAt = now;
      _emit(_snapshot.copyWith(
        lastPublishedAt: now,
        queueDepth: _queue.length,
      ));
      _flushQueue();
    } catch (_) {
      _enqueue(update);
      _emit(_snapshot.copyWith(
        status: RiderLiveTrackingStatus.offline,
        message: 'Offline. Tracking will retry shortly.',
        queueDepth: _queue.length,
      ));
    }
  }

  void _enqueue(_QueuedLocationUpdate update) {
    _queue.addLast(update);
    while (_queue.length > RiderLiveTrackingPolicy.maxQueuedUpdates) {
      _queue.removeFirst();
    }
  }

  Future<void> _flushQueue() async {
    final deliveryId = _deliveryId;
    final riderId = _riderId;
    if (deliveryId == null || riderId == null || _queue.isEmpty) return;
    final now = DateTime.now();
    while (_queue.isNotEmpty) {
      final update = _queue.removeFirst();
      if (now.difference(update.createdAt) >
          RiderLiveTrackingPolicy.staleUpdateAfter) {
        continue;
      }
      try {
        await _writeUpdate(
          deliveryId: deliveryId,
          riderId: riderId,
          update: update,
        );
        _lastPublishedPosition = update.position;
        _lastPublishedAt = now;
      } catch (_) {
        _queue.addFirst(update);
        return;
      }
    }
    _emit(_snapshot.copyWith(
      status: _snapshot.status == RiderLiveTrackingStatus.offline
          ? RiderLiveTrackingStatus.reconnecting
          : _snapshot.status,
      queueDepth: _queue.length,
    ));
  }

  Future<void> _writeUpdate({
    required String deliveryId,
    required String riderId,
    required _QueuedLocationUpdate update,
  }) async {
    final position = update.position;
    final gpsSignalQuality = RiderLiveTrackingPolicy.signalQuality(position);
    final gpsStatus = RiderLiveTrackingPolicy.isUsableAccuracy(position)
        ? 'active'
        : 'poorAccuracy';
    final trackingHealth = <String, dynamic>{
      'gpsStatus': gpsStatus,
      'gpsSignalQuality': gpsSignalQuality,
      'accuracyMeters': position.accuracy,
      'lastFixClientAt': Timestamp.fromDate(update.createdAt),
      'lastBackendUploadAt': FieldValue.serverTimestamp(),
      'fresh': true,
      'backgroundCapable': !kIsWeb,
      'queueDepth': _queue.length,
    };
    final payload = <String, dynamic>{
      'riderId': riderId,
      'activeDeliveryId': deliveryId,
      'deliveryId': deliveryId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'heading': position.heading,
      'speed': position.speed,
      'status': update.trackingStatus,
      'trackingStatus': 'live',
      'gpsStatus': gpsStatus,
      'gpsSignalQuality': gpsSignalQuality,
      'gpsAccuracyMeters': position.accuracy,
      'lastGpsUpdateClientAt': Timestamp.fromDate(update.createdAt),
      'lastBackendUploadAt': FieldValue.serverTimestamp(),
      'trackingHealth': trackingHealth,
      'clientRecordedAt': Timestamp.fromDate(update.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'riderLiveLocation': {
        'geopoint': GeoPoint(position.latitude, position.longitude),
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'accuracyMeters': position.accuracy,
        'heading': position.heading,
        'speed': position.speed,
        'gpsStatus': gpsStatus,
        'gpsSignalQuality': gpsSignalQuality,
        'clientRecordedAt': Timestamp.fromDate(update.createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    };
    final trackingRef = _firestore
        .collection('deliveryRequests')
        .doc(deliveryId)
        .collection('tracking')
        .doc('liveLocation');
    final activeRef = _firestore.collection('activeDeliveries').doc(deliveryId);
    final batch = _firestore.batch();
    batch.set(trackingRef, payload, SetOptions(merge: true));
    batch.set(
      activeRef,
      {
        'deliveryId': deliveryId,
        'riderId': riderId,
        'status': update.trackingStatus,
        'riderLiveLocation': payload['riderLiveLocation'],
        'trackingHealth': trackingHealth,
        'lastBackendUploadAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> _writeStop({
    required String deliveryId,
    required String riderId,
    required String status,
  }) async {
    await _firestore
        .collection('deliveryRequests')
        .doc(deliveryId)
        .collection('tracking')
        .doc('liveLocation')
        .set({
      'riderId': riderId,
      'activeDeliveryId': deliveryId,
      'deliveryId': deliveryId,
      'trackingStatus': 'stopped',
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _emit(RiderLiveTrackingSnapshot next) {
    _snapshot = next;
    if (!_states.isClosed) _states.add(next);
  }
}

class _QueuedLocationUpdate {
  const _QueuedLocationUpdate({
    required this.position,
    required this.createdAt,
    required this.trackingStatus,
  });

  final Position position;
  final DateTime createdAt;
  final String trackingStatus;
}
