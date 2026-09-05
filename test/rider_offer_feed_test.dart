import 'package:flutter_test/flutter_test.dart';
import 'package:circum_rider/app/rider_jobs/rider_offer_feed.dart';

void main() {
  Map<String, dynamic> response(
          {String rider = 'rider', bool eligible = true}) =>
      {
        'riderId': rider,
        'eligible': eligible,
        'nearestRequests': [
          {
            'deliveryId': 'job',
            'projectionVersion': 2,
            'offerExpiresAt': DateTime.now().millisecondsSinceEpoch + 30000,
            'pickupLocality': 'Camden',
            'dropoffLocality': 'Islington',
            'riderEarning': 6,
          },
        ],
      };

  test('only current owned server-authorized offers reach the card', () async {
    final feed = RiderOfferFeed(load: () async => response());
    expect(await feed.refresh(riderId: 'rider'), hasLength(1));
    expect(await feed.refresh(riderId: 'other'), isEmpty);
    expect(
      await RiderOfferFeed(load: () async => response(eligible: false))
          .refresh(riderId: 'rider'),
      isEmpty,
    );
  });

  test('expired and unversioned offers are discarded', () async {
    final data = response();
    final row = (data['nearestRequests'] as List).single as Map;
    row['offerExpiresAt'] = DateTime.now().millisecondsSinceEpoch - 1;
    expect(
        await RiderOfferFeed(load: () async => data).refresh(riderId: 'rider'),
        isEmpty);
    row['offerExpiresAt'] = DateTime.now().millisecondsSinceEpoch + 30000;
    row.remove('projectionVersion');
    expect(
        await RiderOfferFeed(load: () async => data).refresh(riderId: 'rider'),
        isEmpty);
  });

  test('failed authorization refresh first clears any offer list', () async {
    final feed = RiderOfferFeed(load: () async => throw StateError('offline'));
    expect(await feed.watch(riderId: 'rider').first, isEmpty);
  });
}
