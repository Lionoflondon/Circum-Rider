import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

enum RiderActiveDeliveryResolutionKind { none, active, repaired, unavailable }

class RiderActiveDeliveryResolution {
  const RiderActiveDeliveryResolution._({
    required this.kind,
    this.deliveryId,
    this.data,
    this.status,
    this.reason,
  });

  const RiderActiveDeliveryResolution.none()
    : this._(kind: RiderActiveDeliveryResolutionKind.none);

  const RiderActiveDeliveryResolution.active({
    required String deliveryId,
    required Map<String, dynamic> data,
    required String status,
  }) : this._(
         kind: RiderActiveDeliveryResolutionKind.active,
         deliveryId: deliveryId,
         data: data,
         status: status,
       );

  const RiderActiveDeliveryResolution.repaired(String reason)
    : this._(kind: RiderActiveDeliveryResolutionKind.repaired, reason: reason);

  const RiderActiveDeliveryResolution.unavailable(String reason)
    : this._(
        kind: RiderActiveDeliveryResolutionKind.unavailable,
        reason: reason,
      );

  final RiderActiveDeliveryResolutionKind kind;
  final String? deliveryId;
  final Map<String, dynamic>? data;
  final String? status;
  final String? reason;

  bool get hasActiveDelivery =>
      kind == RiderActiveDeliveryResolutionKind.active;
}

/// Resolves the one backend-authoritative Rider active job pointer.
class RiderActiveDeliveryResolver {
  RiderActiveDeliveryResolver({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : firestore = firestore ?? FirebaseFirestore.instance,
       functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  static const restorableStatuses = <String>{
    'accepted',
    'navigating_to_pickup',
    'arrived_at_pickup',
    'waiting',
    'pickup_verification',
    'pickup_verified',
    'collected',
    'navigating_to_dropoff',
    'arrived_at_dropoff',
    'pin_required',
    'issue_reported',
  };

  static const terminalStatuses = <String>{
    'delivered',
    'completed',
    'complete',
    'cancelled',
    'canceled',
    'failed',
    'expired',
    'no_show',
    'disputed',
    'reassigned',
    'assignment_removed',
  };

  static String normalizeStatus(dynamic value) {
    final status = '$value'.trim().toLowerCase();
    switch (status) {
      case 'outfordelivery':
      case 'out_for_delivery':
      case 'in_transit':
      case 'travelling_to_dropoff':
        return 'navigating_to_dropoff';
      case 'travelling_to_pickup':
      case 'waiting_at_pickup':
        return status == 'waiting_at_pickup'
            ? 'waiting'
            : 'navigating_to_pickup';
      case 'picked_up':
        return 'collected';
      case 'recipient_verification':
      case 'dropoff_verification_required':
      case 'awaiting_pin':
        return 'pin_required';
      default:
        return status;
    }
  }

  static bool isRestorableStatus(dynamic value) =>
      restorableStatuses.contains(normalizeStatus(value));

  static bool isTerminalStatus(dynamic value) =>
      terminalStatuses.contains(normalizeStatus(value));

  /// Modern fields win; legacy `assignedRider` is retained only for old rows.
  static bool assignedToRider(Map<String, dynamic> data, String riderId) {
    final value =
        data['assignedRiderId'] ??
        data['riderId'] ??
        data['assignedRider'] ??
        data['driverId'] ??
        data['assignedDriverId'];
    return '$value'.trim() == riderId;
  }

  Future<RiderActiveDeliveryResolution> resolve({
    required String riderId,
    bool repairStalePointer = true,
  }) async {
    final presence = await firestore
        .collection('riderPresence')
        .doc(riderId)
        .get();
    final presenceData = presence.data() ?? const <String, dynamic>{};
    final activeId =
        '${presenceData['activeDeliveryId'] ?? presenceData['currentDeliveryId'] ?? ''}'
            .trim();
    if (activeId.isEmpty) return const RiderActiveDeliveryResolution.none();

    final delivery = await firestore
        .collection('deliveryRequests')
        .doc(activeId)
        .get();
    if (!delivery.exists) {
      return _repairOrUnavailable(
        riderId: riderId,
        repairStalePointer: repairStalePointer,
        reason: 'missing_delivery',
      );
    }

    final data = delivery.data() ?? const <String, dynamic>{};
    if (!assignedToRider(data, riderId)) {
      return _repairOrUnavailable(
        riderId: riderId,
        repairStalePointer: repairStalePointer,
        reason: 'assignment_mismatch',
      );
    }

    final status = normalizeStatus(
      data['deliveryStage'] ?? data['deliveryStatus'] ?? data['status'],
    );
    if (isTerminalStatus(status)) {
      return _repairOrUnavailable(
        riderId: riderId,
        repairStalePointer: repairStalePointer,
        reason: 'terminal_delivery',
      );
    }
    if (!isRestorableStatus(status)) {
      return RiderActiveDeliveryResolution.unavailable('unknown_status');
    }
    return RiderActiveDeliveryResolution.active(
      deliveryId: delivery.id,
      data: data,
      status: status,
    );
  }

  Future<RiderActiveDeliveryResolution> _repairOrUnavailable({
    required String riderId,
    required bool repairStalePointer,
    required String reason,
  }) async {
    if (!repairStalePointer) {
      return RiderActiveDeliveryResolution.unavailable(reason);
    }
    try {
      await functions.httpsCallable('goOffline').call();
      return RiderActiveDeliveryResolution.repaired(reason);
    } catch (_) {
      return RiderActiveDeliveryResolution.unavailable('$reason:repair_failed');
    }
  }
}
