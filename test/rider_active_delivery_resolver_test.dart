import 'package:circum_rider/app/rider_jobs/rider_active_delivery_resolver.dart';
import 'package:circum_rider/app/home/bloc/home_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RiderActiveDeliveryResolver', () {
    test('normalizes canonical and legacy lifecycle aliases', () {
      expect(
        RiderActiveDeliveryResolver.normalizeStatus('outForDelivery'),
        'navigating_to_dropoff',
      );
      expect(
        RiderActiveDeliveryResolver.normalizeStatus('in_transit'),
        'navigating_to_dropoff',
      );
      expect(
        RiderActiveDeliveryResolver.normalizeStatus('picked_up'),
        'collected',
      );
      expect(
        RiderActiveDeliveryResolver.normalizeStatus('waiting_at_pickup'),
        'waiting',
      );
    });

    test('recognizes every canonical restorable stage', () {
      for (final status in [
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
      ]) {
        expect(
          RiderActiveDeliveryResolver.isRestorableStatus(status),
          isTrue,
          reason: status,
        );
      }
    });

    test('never restores terminal stages', () {
      for (final status in [
        'delivered',
        'completed',
        'cancelled',
        'failed',
        'expired',
        'no_show',
      ]) {
        expect(
          RiderActiveDeliveryResolver.isTerminalStatus(status),
          isTrue,
          reason: status,
        );
        expect(
          RiderActiveDeliveryResolver.isRestorableStatus(status),
          isFalse,
          reason: status,
        );
      }
    });

    test(
      'uses modern assignment fields before legacy compatibility fields',
      () {
        expect(
          RiderActiveDeliveryResolver.assignedToRider({
            'assignedRiderId': 'rider-1',
          }, 'rider-1'),
          isTrue,
        );
        expect(
          RiderActiveDeliveryResolver.assignedToRider({
            'assignedRider': 'rider-1',
          }, 'rider-1'),
          isTrue,
        );
        expect(
          RiderActiveDeliveryResolver.assignedToRider({
            'assignedRiderId': 'rider-2',
            'riderId': 'rider-1',
          }, 'rider-1'),
          isFalse,
        );
      },
    );

    test('unknown statuses fail closed', () {
      expect(
        RiderActiveDeliveryResolver.isRestorableStatus('surprise_state'),
        isFalse,
      );
      expect(
        RiderActiveDeliveryResolver.isTerminalStatus('surprise_state'),
        isFalse,
      );
    });

    test('presence with an active pointer is never projected as available', () {
      final now = DateTime.now();
      final availability = RiderAvailability.fromPresence(
        {
          'isOnline': true,
          'availabilityStatus': 'busy',
          'activeDeliveryId': 'delivery-1',
          'dispatchEligible': true,
          'lastHeartbeatAt': now,
          'currentLocation': {
            'updatedAt': now,
            'accuracyMeters': 10,
          },
        },
        now: now,
      );
      expect(availability.status, RiderAvailabilityStatus.activeDelivery);
      expect(availability.isOnline, isTrue);
      expect(availability.activeDeliveryId, 'delivery-1');
    });

    test('live drop-off fixture restores as an ordinary actionable stage', () {
      const delivery = <String, dynamic>{
        'status': 'arrived_at_dropoff',
        'deliveryStatus': 'arrived_at_dropoff',
        'deliveryStage': 'arrived_at_dropoff',
        'paymentStatus': 'paid',
        'assignedRiderId': 'founder-rider',
      };
      expect(
        RiderActiveDeliveryResolver.assignedToRider(delivery, 'founder-rider'),
        isTrue,
      );
      expect(
        RiderActiveDeliveryResolver.normalizeStatus(
          delivery['deliveryStage'],
        ),
        'arrived_at_dropoff',
      );
      expect(
        RiderActiveDeliveryResolver.isRestorableStatus(
          delivery['deliveryStage'],
        ),
        isTrue,
      );
      expect(delivery.containsKey('receiverPin'), isFalse);
    });
  });
}
