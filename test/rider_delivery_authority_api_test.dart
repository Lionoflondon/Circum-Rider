import 'dart:convert';
import 'dart:io';

import 'package:circum_rider/app/rider_delivery_authority_api.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Rider authority preserves callable Auth and App Check envelope',
      () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
          jsonEncode({
            'result': {'status': 'delivered'}
          }),
          200);
    });

    final result = await invokeRiderDeliveryAuthorityWithTokens(
      'completeDelivery',
      const {'deliveryId': 'delivery-1', 'deliveryPin': '123456'},
      idToken: 'id-token',
      appCheckToken: 'app-check-token',
      client: client,
    );

    expect(captured.method, 'POST');
    expect(captured.url.host, contains('circum-rider-delivery-authority'));
    expect(captured.url.path, '/completeDelivery');
    expect(captured.headers['authorization'], 'Bearer id-token');
    expect(captured.headers['x-firebase-appcheck'], 'app-check-token');
    expect(jsonDecode(captured.body), {
      'data': {'deliveryId': 'delivery-1', 'deliveryPin': '123456'},
    });
    expect(result, {'status': 'delivered'});
  });

  test('Cloud Run errors retain callable status and message', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'error': {
              'status': 'FAILED_PRECONDITION',
              'message': 'This scheduled delivery is not ready for pickup yet.',
            },
          }),
          400,
        ));

    await expectLater(
      invokeRiderDeliveryAuthorityWithTokens(
        'completeDelivery',
        const {'deliveryId': 'delivery-1'},
        idToken: 'id-token',
        appCheckToken: 'app-check-token',
        client: client,
      ),
      throwsA(isA<FirebaseFunctionsException>()
          .having((error) => error.code, 'code', 'failed-precondition')
          .having((error) => error.message, 'message',
              'This scheduled delivery is not ready for pickup yet.')),
    );
  });

  test('all active migrated Rider callers use Cloud Run', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in sources) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains("httpsCallable('getAvailableRequests')")),
          reason: file.path);
    }
    final controller = File('lib/app/rider_jobs/rider_delivery_controller.dart')
        .readAsStringSync();
    expect(controller, contains("action == 'verify_receiver_pin'"));
    expect(controller, contains('completeDeliveryViaCloudRun'));
    expect(
        controller, contains("httpsCallable('updateDeliveryTrackingStatus')"));
  });
}
