import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:circum_rider/app/rider_jobs/rider_offer_card.dart';

Map<String, dynamic> _realisticDeliveryDoc() {
  return {
    'requestId': 'request-123',
    'pickupDetails': {
      'locality': 'Lewisham',
      'formattedAddress': '282 Lewisham High Street, London SE13 6JZ',
      'position': {'latitude': 51.46, 'longitude': -0.01},
    },
    'dropoffDetails': {
      'locality': 'Croydon',
      'formattedAddress': '4 Edridge Road, Croydon CR0 1GD',
      'position': {'latitude': 51.37, 'longitude': -0.10},
    },
    'pickupLocality': 'Lewisham',
    'dropoffLocality': 'Croydon',
    'normalizedItemName': 'MacBook',
    'packageDescription': 'Laptop in protective sleeve',
    'riderEarning': 8.50,
    'currency': 'GBP',
    'minimumVehicle': 'Car',
    'weightKg': 3,
  };
}

void main() {
  testWidgets('canonical Sender addresses survive delivery mapping and render',
      (tester) async {
    const senderPickup = {
      'address': '282 Lewisham High Street, London SE13 6JZ',
      'subAddress': 'London SE13 6JZ',
      'locality': 'Lewisham',
      'coordinates': {'lat': 51.46, 'lng': -0.01},
    };
    const senderDropoff = {
      'address': '4 Edridge Road, Croydon CR0 1GD',
      'subAddress': 'Croydon CR0 1GD',
      'locality': 'Croydon',
      'coordinates': {'lat': 51.37, 'lng': -0.10},
    };
    final delivery = {
      'pickupDetails': {
        'address': senderPickup['address'],
        'locality': senderPickup['locality'],
        'position': senderPickup['coordinates'],
      },
      'dropoffDetails': {
        'address': senderDropoff['address'],
        'locality': senderDropoff['locality'],
        'position': senderDropoff['coordinates'],
      },
      'pickupAddress': senderPickup['address'],
      'pickupLocality': senderPickup['locality'],
      'dropoffAddress': senderDropoff['address'],
      'dropoffLocality': senderDropoff['locality'],
      'riderEarning': 8.50,
    };
    final offer = RiderJobOffer.fromFirestore(
      docId: 'delivery-address-contract',
      data: delivery,
    );

    expect(offer.pickupAddress, senderPickup['address']);
    expect(offer.dropoffAddress, senderDropoff['address']);
    expect(offer.pickupArea, senderPickup['locality']);
    expect(offer.dropoffArea, senderDropoff['locality']);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 390,
          height: 844,
          child: RiderOfferCard(
            offer: offer,
            riderRank: 'Sentinel',
            accepting: false,
            onAccept: () {},
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text(senderPickup['address']! as String), findsOneWidget);
    expect(find.text(senderDropoff['address']! as String), findsOneWidget);
    expect(find.text('Lewisham → Croydon'), findsOneWidget);
  });

  test('parses backend locality and item fields without exposing raw maps', () {
    final offer = RiderJobOffer.fromFirestore(
      docId: 'delivery-123',
      data: _realisticDeliveryDoc(),
    );

    expect(offer.pickupArea, 'Lewisham');
    expect(offer.dropoffArea, 'Croydon');
    expect(offer.pickupArea, isNot(contains('latitude')));
    expect(offer.dropoffArea, isNot(contains('longitude')));
    expect(offer.parcelGuidance, 'MacBook');
    expect(offer.pickupAddress, contains('282 Lewisham High Street'));
  });

  test('uses flattened locality when nested locality is absent', () {
    final data = _realisticDeliveryDoc()
      ..['pickupDetails'] = {
        'position': {'latitude': 0, 'longitude': 0},
      }
      ..['dropoffDetails'] = {
        'position': {'latitude': 0, 'longitude': 0},
      };

    final offer = RiderJobOffer.fromFirestore(
      docId: 'delivery-123',
      data: data,
    );

    expect(offer.pickupArea, 'Lewisham');
    expect(offer.dropoffArea, 'Croydon');
  });

  test('never stringifies missing detail maps', () {
    final offer = RiderJobOffer.fromFirestore(
      docId: 'delivery-123',
      data: {'pickupDetails': {}, 'dropoffDetails': {}},
    );

    expect(offer.pickupArea, 'Location pending');
    expect(offer.dropoffArea, 'Location pending');
    expect(offer.pickupAddress, 'Address pending');
    expect(offer.dropoffAddress, 'Address pending');
  });

  test('legacy item field remains supported', () {
    final offer = RiderJobOffer.fromFirestore(
      docId: 'delivery-123',
      data: {'itemName': 'Books'},
    );

    expect(offer.parcelGuidance, 'Books');
  });

  test('canonical now wins over stale scheduling metadata', () {
    final offer = RiderJobOffer.fromFirestore(
      docId: 'now-1',
      data: {
        'deliveryTime': {
          'type': 'now',
          'scheduledDate': '2099-01-01',
          'scheduledWindow': 'Morning',
        },
        'isScheduled': true,
        'scheduledTime': '2099-01-01',
      },
    );

    expect(offer.warningChips, isNot(contains('Scheduled')));
    expect(offer.pickupTiming, 'ASAP');
  });

  test('canonical scheduled data drives chip and timing', () {
    final offer = RiderJobOffer.fromFirestore(
      docId: 'scheduled-1',
      data: {
        'deliveryTime': {
          'type': 'scheduled',
          'scheduledDate': '2099-01-01',
          'scheduledWindow': 'Morning',
        },
      },
    );

    expect(offer.warningChips, contains('Scheduled'));
    expect(offer.pickupTiming, '2099-01-01 · Morning');
  });

  test('canonical scheduled summary takes precedence', () {
    final offer = RiderJobOffer.fromFirestore(
      docId: 'scheduled-2',
      data: {
        'deliveryTime': {
          'type': 'scheduled',
          'summary': 'Tomorrow afternoon',
          'scheduledDate': '2099-01-01',
        },
      },
    );

    expect(offer.warningChips, contains('Scheduled'));
    expect(offer.pickupTiming, 'Tomorrow afternoon');
  });

  test('legacy scheduled data remains supported', () {
    final offer = RiderJobOffer.fromFirestore(
      docId: 'legacy-scheduled',
      data: {'isScheduled': true, 'scheduledTime': 'Tomorrow · Morning'},
    );

    expect(offer.warningChips, contains('Scheduled'));
    expect(offer.pickupTiming, 'Tomorrow · Morning');
  });

  testWidgets('shows an overflow chip instead of silently dropping badges',
      (tester) async {
    const offer = RiderJobOffer(
      id: 'delivery-123',
      requestId: 'request-123',
      pickupArea: 'Lewisham',
      dropoffArea: 'Croydon',
      pickupAddress: 'Pickup',
      dropoffAddress: 'Drop-off',
      earnings: 8.50,
      currency: 'GBP',
      distanceText: '3 km',
      timeText: '15 min',
      parcelGuidance: 'MacBook',
      minimumVehicle: 'Van',
      weightText: '10kg',
      pickupTiming: 'ASAP',
      warningChips: [
        'Vanguard',
        'Gift',
        'Scheduled',
        'Business',
        'Heavy',
        'Marketplace',
      ],
      raw: {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 844,
            child: RiderOfferCard(
              offer: offer,
              riderRank: 'Rider',
              accepting: false,
              onAccept: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('more'), findsOneWidget);
  });
}
