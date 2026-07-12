import 'rider_points_rules.dart';

enum RiderVehicleClass {
  bike,
  motorbike,
  car,
  van,
}

class RiderDispatchDecision {
  final bool eligible;
  final String? reason;

  const RiderDispatchDecision._(this.eligible, this.reason);

  const RiderDispatchDecision.allow() : this._(true, null);

  const RiderDispatchDecision.block(String reason) : this._(false, reason);
}

class RiderDispatchContext {
  final String riderId;
  final List<String> vehicles;
  final String? activeDeliveryId;
  final Iterable<String> reservedScheduledJobIds;
  final int trustPoints;
  final bool founderOverride;

  const RiderDispatchContext({
    required this.riderId,
    required this.vehicles,
    this.activeDeliveryId,
    this.reservedScheduledJobIds = const [],
    this.trustPoints = 0,
    this.founderOverride = false,
  });

  bool get hasActiveDelivery => (activeDeliveryId ?? '').trim().isNotEmpty;
}

class RiderDispatchPolicy {
  static const Set<String> availableStatuses = {
    'requested',
    'available',
  };

  static const Set<String> unavailableStatuses = {
    'accepted',
    'assigned',
    'reserved',
    'cancelled',
    'completed',
    'expired',
    'withdrawn',
    'ineligible',
  };

  static RiderDispatchDecision visibleToRider({
    required Map<String, dynamic> job,
    required RiderDispatchContext rider,
    DateTime? now,
  }) {
    if (rider.founderOverride) {
      return _baseAvailability(job: job, rider: rider, now: now);
    }

    final base = _baseAvailability(job: job, rider: rider, now: now);
    if (!base.eligible) return base;

    if (rider.hasActiveDelivery && !isScheduled(job)) {
      return const RiderDispatchDecision.block(
        'Finish your active delivery before accepting another immediate job.',
      );
    }

    final trustDecision = _trustEligibility(job, rider.trustPoints);
    if (!trustDecision.eligible) return trustDecision;

    final vehicleDecision = _vehicleEligibility(job, rider.vehicles);
    if (!vehicleDecision.eligible) return vehicleDecision;

    if (_stringList(job['eligibleRiders']).isNotEmpty &&
        !_stringList(job['eligibleRiders']).contains(rider.riderId)) {
      return const RiderDispatchDecision.block(
        'This delivery is reserved for another eligible Rider.',
      );
    }

    return const RiderDispatchDecision.allow();
  }

  static RiderDispatchDecision canAccept({
    required Map<String, dynamic> job,
    required RiderDispatchContext rider,
    DateTime? now,
  }) {
    final visible = visibleToRider(job: job, rider: rider, now: now);
    if (!visible.eligible) return visible;

    if (isScheduled(job) && conflictsWithReservedSchedule(job, rider)) {
      return const RiderDispatchDecision.block(
        'This scheduled delivery conflicts with an existing reservation.',
      );
    }

    return const RiderDispatchDecision.allow();
  }

  static bool isScheduled(Map<String, dynamic> job) {
    return _truthy(job['isScheduled']) ||
        _truthy(job['scheduled']) ||
        _truthy(job['scheduledDelivery']) ||
        job['scheduledAt'] != null ||
        job['scheduledTime'] != null ||
        job['pickupWindowStart'] != null;
  }

  static bool isExpress(Map<String, dynamic> job) {
    final text =
        '${job['priority'] ?? job['speed'] ?? job['deliveryType'] ?? job['serviceType'] ?? ''}'
            .toLowerCase();
    return _truthy(job['express']) || text.contains('express');
  }

  static bool isDocumentEligibleForBike(Map<String, dynamic> job) {
    final text =
        '${job['itemName'] ?? job['itemDescription'] ?? job['parcelDescription'] ?? job['packageType'] ?? ''}'
            .toLowerCase();
    final oversized = _truthy(job['oversized']) ||
        _truthy(job['isOversized']) ||
        _truthy(job['heavyDuty']) ||
        _truthy(job['isHeavyDuty']);
    return !oversized &&
        (text.contains('document') ||
            text.contains('passport') ||
            text.contains('licence') ||
            text.contains('license'));
  }

  static String vehicleGuidance(Map<String, dynamic> job) {
    if (isExpress(job) && !requiresLargeVehicle(job)) {
      return 'Bike or Motorbike preferred';
    }
    if (isDocumentEligibleForBike(job)) return 'Bike eligible';
    final vehicle = _firstText(job, const [
      'minimumVehicle',
      'recommendedVehicle',
      'irisRecommendedVehicle',
      'vehicleType',
    ]);
    return vehicle == null ? 'Vehicle guidance pending' : '$vehicle minimum';
  }

  static bool conflictsWithReservedSchedule(
    Map<String, dynamic> job,
    RiderDispatchContext rider,
  ) {
    final id = '${job['requestId'] ?? job['id'] ?? ''}'.trim();
    if (id.isEmpty) return false;
    return rider.reservedScheduledJobIds.contains(id);
  }

  static bool requiresLargeVehicle(Map<String, dynamic> job) {
    final minimum = _firstText(job, const [
      'minimumVehicle',
      'recommendedVehicle',
      'irisRecommendedVehicle',
      'vehicleType',
    ]);
    if (minimum == null) return false;
    final vehicle = parseVehicle(minimum);
    return vehicle == RiderVehicleClass.car || vehicle == RiderVehicleClass.van;
  }

  static RiderVehicleClass parseVehicle(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('van') || normalized.contains('heavy')) {
      return RiderVehicleClass.van;
    }
    if (normalized.contains('car')) return RiderVehicleClass.car;
    if (normalized.contains('motor') || normalized.contains('scooter')) {
      return RiderVehicleClass.motorbike;
    }
    return RiderVehicleClass.bike;
  }

  static bool vehicleMeetsMinimum(String riderVehicle, String minimumVehicle) {
    return _vehicleRank(parseVehicle(riderVehicle)) >=
        _vehicleRank(parseVehicle(minimumVehicle));
  }

  static int _vehicleRank(RiderVehicleClass vehicle) {
    switch (vehicle) {
      case RiderVehicleClass.bike:
        return 1;
      case RiderVehicleClass.motorbike:
        return 2;
      case RiderVehicleClass.car:
        return 3;
      case RiderVehicleClass.van:
        return 4;
    }
  }

  static RiderDispatchDecision _baseAvailability({
    required Map<String, dynamic> job,
    required RiderDispatchContext rider,
    DateTime? now,
  }) {
    final ignored = _stringList(job['ignoredRiders']);
    final rejected = _stringList(job['rejectedRiders']);
    if (ignored.contains(rider.riderId) || rejected.contains(rider.riderId)) {
      return const RiderDispatchDecision.block(
        'This offer is no longer available to you.',
      );
    }

    final assignedRider =
        '${job['riderId'] ?? job['assignedRiderId'] ?? ''}'.trim();
    if (assignedRider.isNotEmpty && assignedRider != rider.riderId) {
      return const RiderDispatchDecision.block(
        'This delivery has already been assigned.',
      );
    }

    final status = '${job['status'] ?? ''}'.trim().toLowerCase();
    final matchingStatus =
        '${job['matchingStatus'] ?? 'available'}'.trim().toLowerCase();
    if (unavailableStatuses.contains(status) ||
        unavailableStatuses.contains(matchingStatus)) {
      return const RiderDispatchDecision.block(
        'This offer is no longer available.',
      );
    }
    if (status.isNotEmpty && !availableStatuses.contains(status)) {
      return const RiderDispatchDecision.block(
        'This offer is not available for acceptance.',
      );
    }
    if (matchingStatus.isNotEmpty &&
        !availableStatuses.contains(matchingStatus)) {
      return const RiderDispatchDecision.block(
        'This offer is not available for matching.',
      );
    }

    final expiry =
        _date(job['expiresAt'] ?? job['expiryAt'] ?? job['offerExpiresAt']);
    if (expiry != null && expiry.isBefore(now ?? DateTime.now().toUtc())) {
      return const RiderDispatchDecision.block('This offer has expired.');
    }

    return const RiderDispatchDecision.allow();
  }

  static RiderDispatchDecision _trustEligibility(
    Map<String, dynamic> job,
    int trustPoints,
  ) {
    final requiredTrust =
        _int(job['minimumTrustPoints'] ?? job['requiredTrustPoints']);
    if (requiredTrust != null && trustPoints < requiredTrust) {
      return RiderDispatchDecision.block(
        'This delivery requires $requiredTrust trust points.',
      );
    }
    final points = RiderPointsRules.resolve(job);
    if (points.category == RiderJobCategory.vanguard && trustPoints < 0) {
      return const RiderDispatchDecision.block(
        'Vanguard eligibility is not currently available.',
      );
    }
    return const RiderDispatchDecision.allow();
  }

  static RiderDispatchDecision _vehicleEligibility(
    Map<String, dynamic> job,
    List<String> vehicles,
  ) {
    final minimum = _firstText(job, const [
          'minimumVehicle',
          'recommendedVehicle',
          'irisRecommendedVehicle',
          'vehicleType',
        ]) ??
        (isDocumentEligibleForBike(job) ? 'Bike' : null);

    if (minimum == null) return const RiderDispatchDecision.allow();
    final hasSuitableVehicle =
        vehicles.any((vehicle) => vehicleMeetsMinimum(vehicle, minimum));
    if (hasSuitableVehicle) return const RiderDispatchDecision.allow();
    return RiderDispatchDecision.block('Requires $minimum or larger.');
  }

  static String? _firstText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      final text = '$value'.trim();
      if (value != null && text.isNotEmpty && text != 'null') return text;
    }
    return null;
  }

  static List<String> _stringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == 'yes' ||
          normalized == 'required' ||
          normalized == 'included';
    }
    return false;
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('$value');
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    try {
      final dynamic maybeTimestamp = value;
      final date = maybeTimestamp.toDate();
      if (date is DateTime) return date.toUtc();
    } catch (_) {}
    return DateTime.tryParse('$value')?.toUtc();
  }
}
