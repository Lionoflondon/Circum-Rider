import 'dart:async';

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
  rejected,
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

class CallableRiderJobTransactionStore implements RiderJobTransactionStore {
  CallableRiderJobTransactionStore({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  })  : functions = functions ?? _defaultFunctions(),
        firestore = firestore ?? FirebaseFirestore.instance;

  static FirebaseFunctions _defaultFunctions() =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions functions;
  final FirebaseFirestore firestore;
  static const _acceptTimeout = Duration(seconds: 20);
  static const _reconciliationTimeout = Duration(seconds: 10);

  static RiderAcceptResult mapCallableFailure({
    required String code,
    String? message,
  }) {
    if (code == 'already-exists' || code == 'not-found') {
      return RiderAcceptResult(
        status: RiderAcceptStatus.alreadyTaken,
        message: message ?? 'This delivery is no longer available.',
      );
    }
    if (code == 'failed-precondition' || code == 'permission-denied') {
      return RiderAcceptResult(
        status: RiderAcceptStatus.rejected,
        message: message ?? 'This delivery cannot be accepted.',
      );
    }
    return RiderAcceptResult(
      status: RiderAcceptStatus.networkError,
      message:
          message ?? 'We could not accept this delivery. Please try again.',
    );
  }

  static RiderAcceptResult reconcileAssignment({
    required Map<String, dynamic>? delivery,
    required String riderId,
  }) {
    if (delivery == null) {
      return const RiderAcceptResult(
        status: RiderAcceptStatus.networkError,
        message:
            'We could not confirm the delivery assignment. Refresh and try again.',
      );
    }
    final assigned =
        '${delivery['riderId'] ?? delivery['assignedRiderId'] ?? ''}'.trim();
    final status = '${delivery['status'] ?? delivery['deliveryStatus'] ?? ''}'
        .trim()
        .toLowerCase();
    if (assigned == riderId &&
        const {
          'accepted',
          'assigned',
          'navigating_to_pickup',
          'arrived_at_pickup',
          'pickup_verified',
          'collected',
          'picked_up',
          'navigating_to_dropoff',
          'arrived_at_dropoff',
        }.contains(status)) {
      return RiderAcceptResult(
        status: RiderAcceptStatus.accepted,
        message: 'Delivery accepted.',
        patch: delivery,
      );
    }
    if (assigned.isNotEmpty && assigned != riderId) {
      return const RiderAcceptResult(
        status: RiderAcceptStatus.alreadyTaken,
        message: 'This delivery has already been accepted.',
      );
    }
    return const RiderAcceptResult(
      status: RiderAcceptStatus.networkError,
      message: 'Acceptance could not be confirmed. Refresh and try again.',
    );
  }

  Future<RiderAcceptResult> _reconcile({
    required String jobId,
    required String riderId,
  }) async {
    DocumentSnapshot<Map<String, dynamic>> snapshot =
        await firestore.collection('deliveryRequests').doc(jobId).get();
    if (!snapshot.exists) {
      final byRequestId = await firestore
          .collection('deliveryRequests')
          .where('requestId', isEqualTo: jobId)
          .limit(1)
          .get();
      if (byRequestId.docs.isNotEmpty) snapshot = byRequestId.docs.first;
    }
    return reconcileAssignment(delivery: snapshot.data(), riderId: riderId);
  }

  @override
  Future<RiderAcceptResult> acceptInTransaction({
    required String jobId,
    required RiderProfileSnapshot rider,
  }) async {
    try {
      final response = await functions
          .httpsCallable('acceptRideRequests')
          .call({'requestId': jobId}).timeout(_acceptTimeout);
      final data = Map<String, dynamic>.from(response.data as Map);
      return RiderAcceptResult(
        status: RiderAcceptStatus.accepted,
        message: 'Delivery accepted.',
        patch: data,
      );
    } on TimeoutException {
      try {
        return await _reconcile(
          jobId: jobId,
          riderId: rider.riderId,
        ).timeout(_reconciliationTimeout);
      } catch (_) {
        return const RiderAcceptResult(
          status: RiderAcceptStatus.networkError,
          message: 'Acceptance could not be confirmed. Refresh and try again.',
        );
      }
    } on FirebaseFunctionsException catch (error) {
      return mapCallableFailure(code: error.code, message: error.message);
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
      return Future.value(
        RiderAcceptResult(
          status: RiderAcceptStatus.blockedByOnboarding,
          message: rider.blockedReason ??
              'Complete your rider approval before accepting deliveries.',
        ),
      );
    }
    return store.acceptInTransaction(jobId: jobId, rider: rider);
  }
}
