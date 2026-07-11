import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class RiderProfileSnapshot {
  final String riderId;
  final String? riderName;
  final String? riderVehicle;
  final String? riderRank;
  final bool canAcceptJobs;
  final String? blockedReason;

  const RiderProfileSnapshot({
    required this.riderId,
    this.riderName,
    this.riderVehicle,
    this.riderRank,
    required this.canAcceptJobs,
    this.blockedReason,
  });
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

        final patch = RiderMarketplaceRules.firstAcceptancePatch(rider: rider);
        transaction.update(ref, patch);
        return RiderAcceptResult(
          status: RiderAcceptStatus.accepted,
          message: 'Delivery accepted.',
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
