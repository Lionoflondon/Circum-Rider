import 'package:cloud_firestore/cloud_firestore.dart';

typedef RiderPresenceLoader = Future<Map<String, dynamic>?> Function(
    String riderId);
typedef RiderDeliveryLoader = Future<Map<String, dynamic>?> Function(
    String deliveryId);

enum RiderActiveDeliveryDisposition {
  none,
  restore,
  terminal,
  missing,
  assignmentMismatch,
  unsupported,
}

class RiderActiveDeliveryResolution {
  const RiderActiveDeliveryResolution({
    required this.disposition,
    this.deliveryId,
    this.rawDelivery,
    this.rawStatus,
    this.normalizedStatus,
  });

  final RiderActiveDeliveryDisposition disposition;
  final String? deliveryId;
  final Map<String, dynamic>? rawDelivery;
  final String? rawStatus;
  final String? normalizedStatus;

  bool get shouldRestore =>
      disposition == RiderActiveDeliveryDisposition.restore;
}

/// Resolves the Rider's active job from backend-authoritative state.
///
/// The loaders are injected so the lifecycle and assignment policy can be
/// tested without making a test depend on a live Firebase project.
class RiderActiveDeliveryResolver {
  RiderActiveDeliveryResolver({
    required this.loadPresence,
    required this.loadDelivery,
  });

  factory RiderActiveDeliveryResolver.firestore({
    FirebaseFirestore? firestore,
  }) {
    final db = firestore ?? FirebaseFirestore.instance;
    return RiderActiveDeliveryResolver(
      loadPresence: (riderId) async =>
          (await db.collection('riderPresence').doc(riderId).get()).data(),
      loadDelivery: (deliveryId) async =>
          (await db.collection('deliveryRequests').doc(deliveryId).get())
              .data(),
    );
  }

  final RiderPresenceLoader loadPresence;
  final RiderDeliveryLoader loadDelivery;

  Future<RiderActiveDeliveryResolution> resolve(String riderId) async {
    final presence = await loadPresence(riderId);
    final deliveryId = _text(presence?['activeDeliveryId']);
    if (deliveryId.isEmpty) {
      return const RiderActiveDeliveryResolution(
        disposition: RiderActiveDeliveryDisposition.none,
      );
    }

    final delivery = await loadDelivery(deliveryId);
    if (delivery == null) {
      return RiderActiveDeliveryResolution(
        disposition: RiderActiveDeliveryDisposition.missing,
        deliveryId: deliveryId,
      );
    }

    final rawStatus = _text(
      delivery['deliveryStage'] ??
          delivery['deliveryStatus'] ??
          delivery['status'],
    ).toLowerCase();
    final normalizedStatus = normalizeStatus(rawStatus);
    if (terminalStatuses.contains(normalizedStatus)) {
      return RiderActiveDeliveryResolution(
        disposition: RiderActiveDeliveryDisposition.terminal,
        deliveryId: deliveryId,
        rawDelivery: delivery,
        rawStatus: rawStatus,
        normalizedStatus: normalizedStatus,
      );
    }
    if (!restorableStatuses.contains(normalizedStatus)) {
      return RiderActiveDeliveryResolution(
        disposition: RiderActiveDeliveryDisposition.unsupported,
        deliveryId: deliveryId,
        rawDelivery: delivery,
        rawStatus: rawStatus,
        normalizedStatus: normalizedStatus,
      );
    }
    if (!assignedToRider(delivery, riderId)) {
      return RiderActiveDeliveryResolution(
        disposition: RiderActiveDeliveryDisposition.assignmentMismatch,
        deliveryId: deliveryId,
        rawDelivery: delivery,
        rawStatus: rawStatus,
        normalizedStatus: normalizedStatus,
      );
    }

    return RiderActiveDeliveryResolution(
      disposition: RiderActiveDeliveryDisposition.restore,
      deliveryId: deliveryId,
      rawDelivery: delivery,
      rawStatus: rawStatus,
      normalizedStatus: normalizedStatus,
    );
  }

  static const terminalStatuses = <String>{
    'delivered',
    'completed',
    'cancelled',
    'canceled',
    'cancelled_by_sender',
    'expired',
    'failed',
    'archived',
  };

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
    'issue_reported',
  };

  static String normalizeStatus(dynamic value) {
    final status = _text(value).toLowerCase();
    switch (status) {
      case 'outfordelivery':
      case 'out_for_delivery':
      case 'in_transit':
      case 'picked_up':
        return status == 'picked_up' ? 'collected' : 'navigating_to_dropoff';
      case 'assigned':
      case 'confirmed':
        return 'accepted';
      default:
        return status;
    }
  }

  static bool assignedToRider(Map<String, dynamic> data, String riderId) {
    final canonicalAssigned = _text(data['assignedRiderId']);
    if (canonicalAssigned.isNotEmpty) return canonicalAssigned == riderId;

    final canonicalRider = _text(data['riderId']);
    if (canonicalRider.isNotEmpty) return canonicalRider == riderId;

    final legacy = [
      data['driverId'],
      data['assignedDriverId'],
      data['assignedRider'],
      data['courierId'],
    ].map(_text).where((value) => value.isNotEmpty).toList();
    return legacy.isNotEmpty && legacy.every((value) => value == riderId);
  }

  static String _text(dynamic value) {
    final text = '$value'.trim();
    return text == 'null' ? '' : text;
  }
}
