import 'package:circum_rider/app/rider_jobs/rider_address_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical venue address remains readable and preserves postcode', () {
    final address = RiderAddressPresentation.fromValue({
      'placeName': 'The Shard',
      'addressLine1': '32 London Bridge Street',
      'locality': 'London',
      'postcode': 'SE1 9SG',
      'position': {
        'geopoint': {'latitude': 51.5045, 'longitude': -0.0865},
      },
      'fullName': 'Sender',
      'contactMethod': 'circum_relay',
    });

    expect(address.formatted,
        'The Shard, 32 London Bridge Street, London, SE1 9SG');
    expect(address.latitude, 51.5045);
    expect(address.formatted, isNot(contains('geopoint')));
    expect(address.formatted, isNot(contains('fullName')));
    expect(address.formatted, isNot(contains('contactMethod')));
  });

  test('legacy scalar address is accepted without serializing sibling maps',
      () {
    final address = RiderAddressPresentation.fromValue({
      'address': 'Flat 190, 4 Edridge Road, Croydon CR0 1GD',
      'position': {
        'geopoint': {'latitude': 51.37, 'longitude': -0.1},
      },
      'recipient': {'fullName': 'Private recipient'},
    });

    expect(address.formatted, 'Flat 190, 4 Edridge Road, Croydon CR0 1GD');
    expect(address.formatted, isNot(contains('{')));
    expect(address.formatted, isNot(contains('recipient')));
    expect(address.formatted, isNot(contains('GeoPoint')));
    expect(address.formatted, isNot(contains('Instance of')));
  });

  test('nested address map never becomes Rider copy', () {
    final address = RiderAddressPresentation.fromValue({
      'address': {
        'line1': '10 High Street',
        'city': 'London',
        'postcode': 'SW1A 1AA',
      },
      'contactMethod': 'circum_relay',
    });

    expect(address.formatted, '10 High Street, London, SW1A 1AA');
    expect(address.formatted, isNot(contains('{')));
    expect(address.formatted, isNot(contains('contactMethod')));
  });
}
