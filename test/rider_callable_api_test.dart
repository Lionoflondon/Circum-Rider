import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:circum_rider/app/rider_callable_api.dart';

void main() {
  test('push registration uses protected authoritative owner and exact token',
      () async {
    var calls = 0;
    final result = await invokeRiderCallable(
        'updateRiderPushToken', {'fcmToken': 'device-token'},
        idToken: 'auth',
        appCheckToken: 'appcheck', client: MockClient((request) async {
      calls++;
      expect(request.url.path, '/updateRiderPushToken');
      expect(request.headers['Authorization'], 'Bearer auth');
      expect(request.headers['X-Firebase-AppCheck'], 'appcheck');
      expect(jsonDecode(request.body), {
        'data': {'fcmToken': 'device-token'}
      });
      return http.Response('{"result":{"ok":true}}', 200);
    }));
    expect(result, {'ok': true});
    expect(calls, 1);
  });
  test('missing security tokens never reach the transport', () async {
    final client = MockClient((_) async => throw StateError('must not send'));
    for (final tokens in [
      [null, 'appcheck'],
      ['auth', null]
    ]) {
      await expectLater(
          invokeRiderCallable('requestRiderWithdrawal', {},
              idToken: tokens[0], appCheckToken: tokens[1], client: client),
          throwsA(isA<FirebaseFunctionsException>()));
    }
  });
  test('ambiguous financial timeout is never automatically retried', () async {
    var calls = 0;
    final response = Completer<http.Response>();
    await expectLater(
        invokeRiderCallable('cancelRiderWithdrawal', {'requestId': 'selected'},
            idToken: 'auth',
            appCheckToken: 'appcheck',
            timeout: const Duration(milliseconds: 5), client: MockClient((_) {
          calls++;
          return response.future;
        })),
        throwsA(isA<FirebaseFunctionsException>()
            .having((e) => e.code, 'code', 'deadline-exceeded')));
    expect(calls, 1);
    response.complete(http.Response('{"result":{"ok":true}}', 200));
  });
  test('server permission denial and details survive transport', () async {
    await expectLater(
        invokeRiderCallable('acceptRideRequests', {'requestId': 'ordinary-job'},
            idToken: 'auth',
            appCheckToken: 'appcheck',
            client: MockClient((_) async => http.Response(
                '{"error":{"status":"PERMISSION_DENIED","message":"Not eligible","details":{"reason":"offline"}}}',
                403))),
        throwsA(isA<FirebaseFunctionsException>()
            .having((e) => e.code, 'code', 'permission-denied')
            .having((e) => e.details, 'details', {'reason': 'offline'})));
  });
}
