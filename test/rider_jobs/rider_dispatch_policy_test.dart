import 'package:circum_rider/app/rider_jobs/rider_accept_controller.dart';
import 'package:circum_rider/app/rider_jobs/rider_dispatch_policy.dart';
import 'package:circum_rider/app/rider_jobs/rider_points_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RiderDispatchPolicy', () {
    const bikeRider = RiderDispatchContext(
      riderId: 'rider-bike',
      vehicles: ['Bike'],
      trustPoints: 250,
    );
    const carRider = RiderDispatchContext(
      riderId: 'rider-car',
      vehicles: ['Car'],
      trustPoints: 250,
    );
    const vanRider = RiderDispatchContext(
      riderId: 'rider-van',
      vehicles: ['Van'],
      trustPoints: 250,
    );

    test('supports every canonical offer type and highest trust only', () {
      final cases = <Map<String, dynamic>, RiderJobCategory>{
        {'status': 'requested'}: RiderJobCategory.standard,
        {'status': 'requested', 'isMarketplace': true}:
            RiderJobCategory.marketplace,
        {'status': 'requested', 'isBusiness': true}: RiderJobCategory.business,
        {'status': 'requested', 'requiresVanguard': true}:
            RiderJobCategory.vanguard,
        {'status': 'requested', 'isHeavyDuty': true, 'minimumVehicle': 'Van'}:
            RiderJobCategory.heavyDuty,
        {'status': 'requested', 'isGift': true}: RiderJobCategory.gift,
        {'status': 'requested', 'isScheduled': true}:
            RiderJobCategory.scheduled,
        {
          'status': 'requested',
          'isHealthPlus': true,
          'requiresVanguard': true,
          'isBusiness': true,
        }: RiderJobCategory.healthPlus,
      };

      for (final entry in cases.entries) {
        final decision = RiderDispatchPolicy.visibleToRider(
          job: entry.key,
          rider: vanRider,
        );
        expect(decision.eligible, isTrue, reason: entry.key.toString());
        expect(RiderPointsRules.resolve(entry.key).category, entry.value);
      }
    });

    test('allows larger suitable vehicles when IRIS recommends smaller', () {
      final job = {
        'status': 'requested',
        'matchingStatus': 'available',
        'irisRecommendedVehicle': 'Bike',
      };

      expect(
        RiderDispatchPolicy.visibleToRider(job: job, rider: carRider).eligible,
        isTrue,
      );
      expect(
        RiderDispatchPolicy.visibleToRider(job: job, rider: vanRider).eligible,
        isTrue,
      );
    });

    test('blocks smaller vehicles for heavy duty or van-required offers', () {
      final job = {
        'status': 'requested',
        'matchingStatus': 'available',
        'isHeavyDuty': true,
        'minimumVehicle': 'Van',
      };

      final decision =
          RiderDispatchPolicy.visibleToRider(job: job, rider: bikeRider);
      expect(decision.eligible, isFalse);
      expect(decision.reason, contains('Van'));
    });

    test('express jobs prefer bike or motorbike when suitable', () {
      expect(
        RiderDispatchPolicy.vehicleGuidance({
          'status': 'requested',
          'express': true,
          'itemName': 'Envelope',
        }),
        'Bike or Motorbike preferred',
      );
    });

    test('documents and passports are bike eligible unless oversized', () {
      expect(
        RiderDispatchPolicy.isDocumentEligibleForBike({
          'itemName': 'Passport documents',
        }),
        isTrue,
      );
      expect(
        RiderDispatchPolicy.isDocumentEligibleForBike({
          'itemName': 'Passport box',
          'oversized': true,
        }),
        isFalse,
      );
    });

    test('scheduled jobs reserve instead of starting immediate navigation', () {
      final patch = RiderMarketplaceRules.acceptancePatch(
        job: {'status': 'requested', 'scheduledAt': '2026-08-01T12:00:00Z'},
        rider: const RiderProfileSnapshot(
          riderId: 'rider-1',
          canAcceptJobs: true,
        ),
      );

      expect(patch['status'], 'reserved');
      expect(patch['matchingStatus'], 'reserved');
      expect(patch['reservationStatus'], 'reserved');
      expect(patch['auditEvent'], 'scheduled_offer_reserved');
      expect(patch, isNot(containsPair('status', 'accepted')));
    });

    test('expired, assigned and ignored offers are not visible', () {
      expect(
        RiderDispatchPolicy.visibleToRider(
          job: {
            'status': 'requested',
            'expiresAt': '2020-01-01T00:00:00Z',
          },
          rider: bikeRider,
        ).eligible,
        isFalse,
      );
      expect(
        RiderDispatchPolicy.visibleToRider(
          job: {'status': 'requested', 'assignedRiderId': 'other'},
          rider: bikeRider,
        ).eligible,
        isFalse,
      );
      expect(
        RiderDispatchPolicy.visibleToRider(
          job: {
            'status': 'requested',
            'ignoredRiders': ['rider-bike'],
          },
          rider: bikeRider,
        ).eligible,
        isFalse,
      );
    });

    test('immediate offers are hidden while Rider has active delivery', () {
      const busyRider = RiderDispatchContext(
        riderId: 'busy',
        vehicles: ['Bike'],
        activeDeliveryId: 'delivery-1',
      );

      expect(
        RiderDispatchPolicy.visibleToRider(
          job: {'status': 'requested'},
          rider: busyRider,
        ).eligible,
        isFalse,
      );
      expect(
        RiderDispatchPolicy.visibleToRider(
          job: {'status': 'requested', 'scheduledAt': '2026-08-01T12:00:00Z'},
          rider: busyRider,
        ).eligible,
        isTrue,
      );
    });

    test('conflicting scheduled reservations are blocked before acceptance',
        () {
      const rider = RiderDispatchContext(
        riderId: 'rider-1',
        vehicles: ['Car'],
        reservedScheduledJobIds: ['scheduled-1'],
      );

      final decision = RiderDispatchPolicy.canAccept(
        job: {
          'id': 'scheduled-1',
          'status': 'requested',
          'scheduledAt': '2026-08-01T12:00:00Z',
        },
        rider: rider,
      );
      expect(decision.eligible, isFalse);
      expect(decision.reason, contains('conflicts'));
    });
  });
}
