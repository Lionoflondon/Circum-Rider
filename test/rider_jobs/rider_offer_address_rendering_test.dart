import 'package:circum_rider/app/rider_jobs/rider_offer_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nested contact maps never render as an address', () {
    final offer = RiderJobOffer.fromFirestore(
      docId: 'delivery-1',
      data: {
        'pickupDetails': {
          'address': {
            'contactMethod': 'circum_relay',
            'fullname': 'Sender',
          },
          'subAddress': 'London SW1A 2AA, United Kingdom',
        },
        'dropoffDetails': {
          'position': {
            'geopoint': {'latitude': 51.5, 'longitude': -0.1}
          },
        },
        'dropoffAddressCanonical': 'London SW1A 1AA, United Kingdom',
      },
    );

    expect(offer.pickupAddress, 'London SW1A 2AA, United Kingdom');
    expect(offer.dropoffAddress, 'London SW1A 1AA, United Kingdom');
    expect(offer.pickupAddress, isNot(contains('{')));
    expect(offer.dropoffAddress, isNot(contains('Instance of')));
  });

  test('map-only contact data fails safely as Address pending', () {
    final offer = RiderJobOffer.fromFirestore(
      docId: 'delivery-2',
      data: {
        'pickupDetails': {
          'address': {'fullname': 'Sender'},
          'position': {'latitude': 51.5, 'longitude': -0.1},
        },
      },
    );

    expect(offer.pickupAddress, 'Address pending');
    expect(offer.pickupAddress, isNot(contains('{')));
  });
}
