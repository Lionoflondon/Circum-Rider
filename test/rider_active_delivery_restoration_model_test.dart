import 'package:circum_rider/app/home/models/contact_info.m.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'secure projected coordinates restore without Firestore GeoPoint internals',
      () {
    final contact = ContactInfo.fromJson({
      'fullname': 'Sender',
      'address': {'private': 'must not stringify'},
      'subAddress': 'London SW1A 2AA, United Kingdom',
      'position': {
        'geopoint': {'latitude': 51.501, 'longitude': -0.141},
      },
    });

    expect(contact.position.geopoint.latitude, 51.501);
    expect(contact.position.geopoint.longitude, -0.141);
    expect(contact.address, isNull);
    expect(contact.subAddress, 'London SW1A 2AA, United Kingdom');
  });
}
