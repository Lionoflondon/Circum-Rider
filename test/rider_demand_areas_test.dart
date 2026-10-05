import 'package:flutter_test/flutter_test.dart';
import 'package:circum_rider/app/rider_jobs/rider_offer_card.dart';
import 'package:circum_rider/app/rider_jobs/rider_demand_areas.dart';

void main() {
  final now = DateTime.utc(2026, 10, 5);
  RiderJobOffer offer(String id, String area,
          {int offset = 30000, int version = 2}) =>
      RiderJobOffer.fromFirestore(docId: id, data: {
        'pickupLocality': area,
        'projectionVersion': version,
        'offerExpiresAt': now.millisecondsSinceEpoch + offset,
      });

  test('counts unique current offers and ranks areas deterministically', () {
    expect(
        riderDemandAreas([
          offer('1', 'Camden'),
          offer('1', 'Camden'),
          offer('2', 'Camden'),
          offer('3', 'Islington'),
          offer('4', 'Old', offset: -1),
          offer('5', 'Legacy', version: 1),
          offer('6', 'Location pending'),
        ], now: now),
        {'Camden': 2, 'Islington': 1});
  });

  test('empty or expired offers never invent demand', () {
    expect(riderDemandAreas([], now: now), isEmpty);
    expect(
        riderDemandAreas([offer('1', 'Camden', offset: 0)], now: now), isEmpty);
  });

  test('shows at most three areas with stable tie ordering', () {
    expect(
        riderDemandAreas([
          offer('1', 'D'),
          offer('2', 'B'),
          offer('3', 'A'),
          offer('4', 'C'),
        ], now: now)
            .keys,
        ['A', 'B', 'C']);
  });
}
