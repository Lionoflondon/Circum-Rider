import 'package:flutter_test/flutter_test.dart';
import 'package:circum_rider/app/rider_jobs/rider_offer_feed.dart';

void main() {
  Map<String, dynamic> response(
          {String rider = 'rider',
          bool eligible = true,
          bool qaOnly = false}) =>
      {
        'riderId': rider,
        'eligible': eligible,
        'qaOnly': qaOnly,
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

  test('malformed rows do not hide other valid available offers', () async {
    final data = response();
    final rows = List<dynamic>.from(data['nearestRequests'] as List);
    data['nearestRequests'] = rows;
    final row = Map<String, dynamic>.from(rows.single as Map);
    rows.addAll([
      {...row, 'deliveryId': null},
      {...row, 'deliveryId': ' '},
      {...row, 'offerExpiresAt': double.infinity},
    ]);
    expect(
        await RiderOfferFeed(load: () async => data).refresh(riderId: 'rider'),
        hasLength(1));
  });

  test('failed authorization refresh first clears any offer list', () async {
    final feed = RiderOfferFeed(load: () async => throw StateError('offline'));
    expect(await feed.watch(riderId: 'rider').first, isEmpty);
  });

  test('QA-only access is server-reported and remains rider-scoped', () async {
    expect(
      await RiderOfferFeed(load: () async => response(qaOnly: true))
          .qaOnlyAccess(riderId: 'rider'),
      isTrue,
    );
    expect(
      await RiderOfferFeed(load: () async => response(qaOnly: true))
          .qaOnlyAccess(riderId: 'other'),
      isFalse,
    );
    expect(
      await RiderOfferFeed(load: () async => response())
          .qaOnlyAccess(riderId: 'rider'),
      isFalse,
    );
  });
}
