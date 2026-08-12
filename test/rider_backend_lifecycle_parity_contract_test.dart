import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider restores every backend-owned happy-path lifecycle state', () {
    final source = File('lib/app/rider_jobs/rider_job_offer_screen.dart')
        .readAsStringSync();

    for (final state in [
      'accepted',
      'assigned',
      'confirmed',
      'navigating_to_pickup',
      'arrived_at_pickup',
      'pickup_verified',
      'collected',
      'navigating_to_dropoff',
      'arrived_at_dropoff',
      'delivered',
    ]) {
      expect(source, contains("case '$state':"), reason: state);
    }
    expect(source, contains('Unknown backend states must never expose'));
  });

  test('Rider sends actions and accepts returned backend status', () {
    final source = File('lib/app/rider_jobs/rider_job_offer_screen.dart')
        .readAsStringSync();

    for (final action in [
      'start_heading_to_pickup',
      'arrived_at_pickup',
      'verify_collection_pin',
      'confirm_collected',
      'start_delivery',
      'arrived_at_dropoff',
      'verify_receiver_pin',
    ]) {
      expect(source, contains("'$action'"), reason: action);
    }
    expect(source, contains('RiderDeliveryStagePolicy.fromRaw(result.status)'));
    expect(source, contains("collection('deliveryRequests')"));
    expect(source, contains('snapshots()'));
  });
}
