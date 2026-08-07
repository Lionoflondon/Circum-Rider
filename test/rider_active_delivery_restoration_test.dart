import 'package:circum_rider/app/home/bloc/home_bloc.dart';
import 'package:circum_rider/app/rider_jobs/rider_active_delivery_restoration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const riderId = 'rider-1';

  Future<RiderActiveDeliveryResolution> resolve({
    Map<String, dynamic> presence = const {
      'activeDeliveryId': 'delivery-1',
    },
    Map<String, dynamic>? delivery,
  }) {
    final resolver = RiderActiveDeliveryResolver(
      loadPresence: (_) async => presence,
      loadDelivery: (_) async => delivery,
    );
    return resolver.resolve(riderId);
  }

  Map<String, dynamic> delivery(String status, {String rider = riderId}) => {
        'status': status,
        'assignedRiderId': rider,
        'riderId': rider,
      };

  test('cold start restores the live ordinary arrived-at-dropoff case',
      () async {
    final result = await resolve(
      delivery: {
        ...delivery('arrived_at_dropoff'),
        'paymentStatus': 'paid',
        'pinRequired': false,
      },
    );

    expect(result.disposition, RiderActiveDeliveryDisposition.restore);
    expect(result.deliveryId, 'delivery-1');
    expect(result.normalizedStatus, 'arrived_at_dropoff');
    expect(result.rawDelivery?['pinRequired'], isFalse);
  });

  test('all canonical active stages restore from the pointer', () async {
    const statuses = [
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
    ];

    for (final status in statuses) {
      final result = await resolve(delivery: delivery(status));
      expect(
        result.disposition,
        RiderActiveDeliveryDisposition.restore,
        reason: status,
      );
    }
  });

  test('legacy movement aliases normalize to the canonical stage', () async {
    final outForDelivery = await resolve(delivery: delivery('outForDelivery'));
    final snakeCase = await resolve(delivery: delivery('out_for_delivery'));
    final transit = await resolve(delivery: delivery('in_transit'));
    final pickedUp = await resolve(delivery: delivery('picked_up'));

    expect(outForDelivery.normalizedStatus, 'navigating_to_dropoff');
    expect(snakeCase.normalizedStatus, 'navigating_to_dropoff');
    expect(transit.normalizedStatus, 'navigating_to_dropoff');
    expect(pickedUp.normalizedStatus, 'collected');
  });

  test('terminal, missing and unsupported pointers are never restored',
      () async {
    final terminal = await resolve(delivery: delivery('delivered'));
    final cancelled = await resolve(delivery: delivery('cancelled'));
    final unsupported = await resolve(delivery: delivery('requested'));
    final missing = await resolve(delivery: null);

    expect(terminal.disposition, RiderActiveDeliveryDisposition.terminal);
    expect(cancelled.disposition, RiderActiveDeliveryDisposition.terminal);
    expect(unsupported.disposition, RiderActiveDeliveryDisposition.unsupported);
    expect(missing.disposition, RiderActiveDeliveryDisposition.missing);
  });

  test('assignment validation fails closed', () async {
    final wrongCanonical = await resolve(
        delivery: delivery('arrived_at_dropoff', rider: 'rider-2'));
    final wrongLegacy = await resolve(
      delivery: {
        'status': 'arrived_at_dropoff',
        'assignedRider': 'rider-2',
      },
    );
    final noPointer =
        await resolve(presence: const {}, delivery: delivery('accepted'));

    expect(wrongCanonical.disposition,
        RiderActiveDeliveryDisposition.assignmentMismatch);
    expect(wrongLegacy.disposition,
        RiderActiveDeliveryDisposition.assignmentMismatch);
    expect(noPointer.disposition, RiderActiveDeliveryDisposition.none);
  });

  test('presence with an active delivery is not presented as available', () {
    final now = DateTime.now();
    final availability = RiderAvailability.fromPresence(
      {
        'activeDeliveryId': 'delivery-1',
        'isOnline': true,
        'availabilityStatus': 'busy',
        'dispatchEligible': true,
        'lastHeartbeatAt': now,
        'currentLocation': {'updatedAt': now},
      },
      now: now,
    );

    expect(availability.hasActiveDelivery, isTrue);
    expect(availability.isOnline, isFalse);
    expect(availability.intendsToBeOnline, isTrue);
  });
}
