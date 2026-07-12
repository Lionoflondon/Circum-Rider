import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'rider_dispatch_policy.dart';

class RiderProfileSnapshot {
  final String riderId;
  final String? riderName;
  final String? riderVehicle;
  final List<String> riderVehicles;
  final String? riderRank;
  final int trustPoints;
  final bool canAcceptJobs;
  final String? blockedReason;
  final String? activeDeliveryId;
  final Iterable<String> reservedScheduledJobIds;

  const RiderProfileSnapshot({
    required this.riderId,
    this.riderName,
    this.riderVehicle,
    this.riderVehicles = const [],
    this.riderRank,
    this.trustPoints = 0,
    required this.canAcceptJobs,
    this.blockedReason,
    this.activeDeliveryId,
    this.reservedScheduledJobIds = const [],
  });

  RiderDispatchContext toDispatchContext() {
    return RiderDispatchContext(
      riderId: riderId,
      vehicles: [
        ...riderVehicles,
        if ((riderVehicle ?? '').trim().isNotEmpty) riderVehicle!,
      ],
      activeDeliveryId: activeDeliveryId,
      reservedScheduledJobIds: reservedScheduledJobIds,
      trustPoints: trustPoints,
    );
  }
}

class RiderOnboardingPolicy {
  static bool canAcceptJobs(Map<String, dynamic> rider) {
    final status = '${rider['riderStatus'] ?? rider['driverStatus'] ?? ''}'
        .trim()
        .toLowerCase();
    final approval = '${rider['approvalStatus'] ?? ''}'.trim().toLowerCase();
    final frozen = rider['isFrozen'] == true || rider['frozen'] == true;
    final suspended =
        rider['isSuspended'] == true || rider['suspended'] == true;
    final closed = rider['isClosed'] == true || rider['closed'] == true;

    if (frozen || suspended || closed) return false;
    if (status == 'active' || status == 'payouts_enabled') return true;
    return approval == 'approved' && status != 'pending';
  }

  static String blockedReason(Map<String, dynamic> rider) {
    if (rider['isFrozen'] == true || rider['frozen'] == true) {
      return 'Your rider account is frozen. Contact support.';
    }
    if (rider['isSuspended'] == true || rider['suspended'] == true) {
      return 'Your account is suspended.';
    }
    if (rider['isClosed'] == true || rider['closed'] == true) {
      return 'Your rider account is closed.';
    }
    return 'Complete your rider approval before accepting deliveries.';
  }
}

class RiderMarketplaceRules {
  static bool canAcceptJob(Map<String, dynamic> freshJob) {
    final status = '${freshJob['status'] ?? ''}'.trim().toLowerCase();
    final matchingStatus =
        '${freshJob['matchingStatus'] ?? ''}'.trim().toLowerCase();
    final assignedRider =
        '${freshJob['riderId'] ?? freshJob['assignedRiderId'] ?? ''}'.trim();

    if (assignedRider.isNotEmpty) return false;
    if (status != 'requested') return false;
    if (matchingStatus.isNotEmpty &&
        matchingStatus != 'available' &&
        matchingStatus != 'requested') {
      return false;
    }
    return true;
  }

  static Map<String, dynamic> firstAcceptancePatch({
    required RiderProfileSnapshot rider,
    DateTime? acceptedAt,
  }) {
    return immediateAcceptancePatch(rider: rider, acceptedAt: acceptedAt)
      ..remove('_scheduledMarker');
  }

  static Map<String, dynamic> immediateAcceptancePatch({
    required RiderProfileSnapshot rider,
    DateTime? acceptedAt,
  }) {
    final timestamp = acceptedAt ?? DateTime.now().toUtc();
    return {
      'status': 'accepted',
      'matchingStatus': 'accepted',
      'riderId': rider.riderId,
      'assignedRiderId': rider.riderId,
      'riderName': rider.riderName,
      'riderVehicle': rider.riderVehicle,
      'riderRank': rider.riderRank,
      'acceptedAt': Timestamp.fromDate(timestamp),
      'updatedAt': Timestamp.fromDate(timestamp),
    };
  }

  static Map<String, dynamic> scheduledReservationPatch({
    required RiderProfileSnapshot rider,
    DateTime? reservedAt,
  }) {
    final timestamp = reservedAt ?? DateTime.now().toUtc();
    return {
      'status': 'reserved',
      'matchingStatus': 'reserved',
      'reservationStatus': 'reserved',
      'riderId': rider.riderId,
      'assignedRiderId': rider.riderId,
      'reservedForRiderId': rider.riderId,
      'riderName': rider.riderName,
      'riderVehicle': rider.riderVehicle,
      'riderRank': rider.riderRank,
      'reservedAt': Timestamp.fromDate(timestamp),
      'updatedAt': Timestamp.fromDate(timestamp),
      'auditEvent': 'scheduled_offer_reserved',
    };
  }

  static Map<String, dynamic> acceptancePatch({
    required Map<String, dynamic> job,
    required RiderProfileSnapshot rider,
    DateTime? acceptedAt,
  }) {
    return RiderDispatchPolicy.isScheduled(job)
        ? scheduledReservationPatch(rider: rider, reservedAt: acceptedAt)
        : immediateAcceptancePatch(rider: rider, acceptedAt: acceptedAt);
  }
}

enum RiderAcceptStatus {
  accepted,
  blockedByOnboarding,
  alreadyTaken,
  networkError,
}

class RiderAcceptResult {
  final RiderAcceptStatus status;
  final String message;
  final Map<String, dynamic>? patch;

  const RiderAcceptResult({
    required this.status,
    required this.message,
    this.patch,
  });

  bool get accepted => status == RiderAcceptStatus.accepted;
}

abstract class RiderJobTransactionStore {
  Future<RiderAcceptResult> acceptInTransaction({
    required String jobId,
    required RiderProfileSnapshot rider,
  });
}

class FirestoreRiderJobTransactionStore implements RiderJobTransactionStore {
  final FirebaseFirestore firestore;

  const FirestoreRiderJobTransactionStore({required this.firestore});

  @override
  Future<RiderAcceptResult> acceptInTransaction({
    required String jobId,
    required RiderProfileSnapshot rider,
  }) async {
    try {
      return firestore.runTransaction((transaction) async {
        final ref = firestore.collection('deliveryRequests').doc(jobId);
        final snapshot = await transaction.get(ref);
        final data = snapshot.data();

        if (!snapshot.exists || data == null) {
          return const RiderAcceptResult(
            status: RiderAcceptStatus.alreadyTaken,
            message: 'This delivery is no longer available.',
          );
        }

        if (!RiderMarketplaceRules.canAcceptJob(data)) {
          return const RiderAcceptResult(
            status: RiderAcceptStatus.alreadyTaken,
            message: 'This delivery has already been accepted.',
          );
        }

        final dispatchDecision = RiderDispatchPolicy.canAccept(
          job: data,
          rider: rider.toDispatchContext(),
        );
        if (!dispatchDecision.eligible) {
          return RiderAcceptResult(
            status: RiderAcceptStatus.alreadyTaken,
            message: dispatchDecision.reason ??
                'This delivery is no longer available.',
          );
        }

        final patch =
            RiderMarketplaceRules.acceptancePatch(job: data, rider: rider);
        transaction.update(ref, patch);
        return RiderAcceptResult(
          status: RiderAcceptStatus.accepted,
          message: RiderDispatchPolicy.isScheduled(data)
              ? 'Scheduled delivery reserved.'
              : 'Delivery accepted.',
          patch: patch,
        );
      });
    } catch (_) {
      return const RiderAcceptResult(
        status: RiderAcceptStatus.networkError,
        message: 'We could not accept this delivery. Please try again.',
      );
    }
  }
}

class CallableRiderJobTransactionStore implements RiderJobTransactionStore {
  CallableRiderJobTransactionStore({FirebaseFunctions? functions})
      : functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions functions;

  @override
  Future<RiderAcceptResult> acceptInTransaction(
      {required String jobId, required RiderProfileSnapshot rider}) async {
    try {
      final response = await functions
          .httpsCallable('acceptRideRequests')
          .call({'requestId': jobId});
      final data = Map<String, dynamic>.from(response.data as Map);
      return RiderAcceptResult(
          status: RiderAcceptStatus.accepted,
          message: 'Delivery accepted.',
          patch: data);
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'already-exists' ||
          error.code == 'not-found' ||
          error.code == 'failed-precondition') {
        return RiderAcceptResult(
            status: RiderAcceptStatus.alreadyTaken,
            message: error.message ?? 'This delivery is no longer available.');
      }
      return RiderAcceptResult(
          status: RiderAcceptStatus.networkError,
          message: error.message ??
              'We could not accept this delivery. Please try again.');
    }
  }
}

class RiderAcceptController {
  final RiderJobTransactionStore store;

  const RiderAcceptController({required this.store});

  Future<RiderAcceptResult> accept({
    required String jobId,
    required RiderProfileSnapshot rider,
  }) {
    if (!rider.canAcceptJobs) {
      return Future.value(RiderAcceptResult(
        status: RiderAcceptStatus.blockedByOnboarding,
        message: rider.blockedReason ??
            'Complete your rider approval before accepting deliveries.',
      ));
    }
    return store.acceptInTransaction(jobId: jobId, rider: rider);
  }
}
