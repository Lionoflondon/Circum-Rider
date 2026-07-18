import 'dart:io';

import 'package:circum_rider/app/rider_jobs/rider_accept_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RiderAcceptController', () {
    test('production acceptance uses only the canonical callable store', () {
      final controllerSource = File(
        'lib/app/rider_jobs/rider_accept_controller.dart',
      ).readAsStringSync();
      final screenSource = File(
        'lib/app/rider_jobs/rider_job_offer_screen.dart',
      ).readAsStringSync();

      expect(controllerSource, contains("httpsCallable('acceptRideRequests')"));
      expect(controllerSource,
          isNot(contains('FirestoreRiderJobTransactionStore')));
      expect(controllerSource, isNot(contains('runTransaction(')));
      expect(
          screenSource, contains('store: CallableRiderJobTransactionStore()'));
    });

    test('blocks riders who are not eligible to accept jobs', () async {
      final store = _MemoryStore({
        'job-1': {'status': 'requested'},
      });
      final controller = RiderAcceptController(store: store);

      final result = await controller.accept(
        jobId: 'job-1',
        rider: const RiderProfileSnapshot(
          riderId: 'rider-1',
          canAcceptJobs: false,
          blockedReason: 'Complete approval.',
        ),
      );

      expect(result.status, RiderAcceptStatus.blockedByOnboarding);
      expect(store.writeCount, 0);
    });

    test('accept transaction writes the first acceptance patch', () async {
      final store = _MemoryStore({
        'job-1': {
          'status': 'requested',
          'matchingStatus': 'available',
        },
      });
      final controller = RiderAcceptController(store: store);

      final result = await controller.accept(
        jobId: 'job-1',
        rider: const RiderProfileSnapshot(
          riderId: 'rider-1',
          riderName: 'Alex Rider',
          riderVehicle: 'Bike',
          canAcceptJobs: true,
        ),
      );

      expect(result.status, RiderAcceptStatus.accepted);
      expect(store.jobs['job-1']?['riderId'], 'rider-1');
      expect(store.jobs['job-1']?['status'], 'accepted');
      expect(store.writeCount, 1);
    });

    test('second simultaneous accept sees already accepted', () async {
      final store = _MemoryStore({
        'job-1': {
          'status': 'requested',
          'matchingStatus': 'available',
        },
      });
      final controller = RiderAcceptController(store: store);

      final first = await controller.accept(
        jobId: 'job-1',
        rider: const RiderProfileSnapshot(
          riderId: 'rider-1',
          canAcceptJobs: true,
        ),
      );
      final second = await controller.accept(
        jobId: 'job-1',
        rider: const RiderProfileSnapshot(
          riderId: 'rider-2',
          canAcceptJobs: true,
        ),
      );

      expect(first.status, RiderAcceptStatus.accepted);
      expect(second.status, RiderAcceptStatus.alreadyTaken);
      expect(second.message, 'This delivery has already been accepted.');
      expect(store.jobs['job-1']?['riderId'], 'rider-1');
      expect(store.writeCount, 1);
    });
  });
}

class _MemoryStore implements RiderJobTransactionStore {
  final Map<String, Map<String, dynamic>> jobs;
  int writeCount = 0;

  _MemoryStore(this.jobs);

  @override
  Future<RiderAcceptResult> acceptInTransaction({
    required String jobId,
    required RiderProfileSnapshot rider,
  }) async {
    final freshJob = jobs[jobId];
    if (freshJob == null) {
      return const RiderAcceptResult(
        status: RiderAcceptStatus.alreadyTaken,
        message: 'This delivery is no longer available.',
      );
    }

    if (!RiderMarketplaceRules.canAcceptJob(freshJob)) {
      return const RiderAcceptResult(
        status: RiderAcceptStatus.alreadyTaken,
        message: 'This delivery has already been accepted.',
      );
    }

    final patch = RiderMarketplaceRules.firstAcceptancePatch(rider: rider);
    jobs[jobId] = {...freshJob, ...patch};
    writeCount += 1;
    return RiderAcceptResult(
      status: RiderAcceptStatus.accepted,
      message: 'Delivery accepted.',
      patch: patch,
    );
  }
}
