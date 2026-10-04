import 'package:flutter_test/flutter_test.dart';
import 'package:circum_rider/app/notifications/rider_push_payload.dart';

void main() {
  test('restart inbox stores routing only and strips personal payloads', () {
    final stored = riderPendingPushData({
      'deliveryId': 'delivery-1',
      'address': 'private address',
      'data': '{"chatId":"chat-1","phone":"private phone"}',
      'entityId': 'x' * 513,
    });
    expect(stored, {
      'deliveryId': 'delivery-1',
      'data': '{"chatId":"chat-1"}',
    });
  });
  test('job tap retains delivery identity ahead of booking identity', () {
    expect(riderOfferId({'deliveryId': 'delivery-1', 'requestId': 'request-1'}),
        'delivery-1');
  });
  test('legacy encoded job identity is supported', () {
    expect(riderOfferId({'data': '{"deliveryId":"legacy-1"}'}), 'legacy-1');
  });
  test('missing malformed and document-path identities fail closed', () {
    for (final payload in <Map<String, dynamic>>[
      {},
      {'data': '{'},
      {'deliveryId': 'other/owner'},
      {'deliveryId': ' '}
    ]) {
      expect(riderOfferId(payload), isNull);
    }
  });
}
