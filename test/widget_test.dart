import 'package:flutter_test/flutter_test.dart';

import 'package:circum_rider/app/home/models/dispatch_request.m..dart';

void main() {
  test('DispatchRequest parses customer app request payloads', () {
    final request = DispatchRequest.fromJson({
      'pickupDetails': {
        'fullname': 'Jane Smith',
        'phone': '+441234567890',
        'address': '10 Downing Street',
        'subAddress': 'Westminster',
        'position': {
          'geohash': 'gcpuv',
          'geopoint': {'_latitude': 51.5034, '_longitude': -0.1276},
        },
      },
      'dropoffDetails': {
        'fullname': 'John Doe',
        'phone': '+449876543210',
        'address': '221B Baker Street',
        'subAddress': 'Marylebone',
        'position': {
          'geohash': 'gcpvh',
          'geopoint': {'_latitude': 51.5237, '_longitude': -0.1585},
        },
      },
      'requestId': 'TRK-1001',
      'code': 'customer-fcm-token',
      'price': 12,
      'currency': 'GBP',
    });

    expect(request.requestId, 'TRK-1001');
    expect(request.price, 12);
    expect(request.currency, 'GBP');
    expect(request.pickupData.address, '10 Downing Street');
  });
}
