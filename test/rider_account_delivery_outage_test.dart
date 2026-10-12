import 'dart:async';
import 'dart:convert';
import 'package:circum_rider/app/account_bootstrap_api.dart';
import 'package:circum_rider/app/rider_map_response.dart';
import 'package:circum_rider/app/rider_delivery_authority_api.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final validResults = <String, Map<String, dynamic>>{
    'profile': {'ok': true},
    'onboarding': {'ok': true, 'onboardingStatus': 'profile_started'},
    'application': {'applicationId': 'r1', 'status': 'submitted'},
    'verification': {'ok': true, 'queued': true},
    'completion': {'status': 'delivered'}
  };
  final routes = <String, Future<Map<String, dynamic>> Function(http.Client)>{
    'profile': (client) => invokeRiderProfileUpdateViaCloudRun(const {},
        idToken: 'auth', appCheckToken: 'check', client: client),
    'onboarding': (client) => invokeAdvanceRiderOnboardingViaCloudRun(const {},
        idToken: 'auth', appCheckToken: 'check', client: client),
    'application': (client) => invokeSubmitRiderApplicationViaCloudRun(const {},
        idToken: 'auth', appCheckToken: 'check', client: client),
    'verification': (client) => invokeRiderVerificationEmailViaCloudRun(
        idToken: 'auth', appCheckToken: 'check', client: client),
    'completion': (client) => invokeRiderDeliveryAuthorityWithTokens(
        'completeDelivery', const {'deliveryId': 'd1'},
        idToken: 'auth', appCheckToken: 'check', client: client),
  };
  for (final route in routes.entries) {
    for (final response in [
      (500, 'Billing is disabled', 'UNAVAILABLE'),
      (503, '<html>Service unavailable</html>', 'UNAVAILABLE'),
      (502, '[]', 'UNAVAILABLE'),
      (401, 'Unauthorized', 'UNAUTHENTICATED'),
      (403, '<html>Forbidden</html>', 'PERMISSION_DENIED'),
      (429, '', 'RESOURCE_EXHAUSTED'),
      (200, '{}', 'INTERNAL'),
      (200, '{"result":{}}', 'INTERNAL'),
      (200, '{"result":{"ok":false}}', 'INTERNAL'),
      (
        200,
        '{"result":{"ok":"true","allowed":"true","status":"unknown"}}',
        'INTERNAL'
      ),
      (200, '{"result":null}', 'INTERNAL'),
      (200, '{"result":[]}', 'INTERNAL'),
      (200, '{"result":true}', 'INTERNAL'),
      (200, '[]', 'INTERNAL'),
      (200, '<html>proxy</html>', 'INTERNAL'),
      (
        200,
        '{"error":{"status":"PERMISSION_DENIED","message":"Access denied"},"result":{"ok":true}}',
        'PERMISSION_DENIED'
      ),
      (400, '{"error":"bad request"}', 'INTERNAL'),
    ]) {
      test('${route.key} rejects ${response.$1} ${response.$2}', () async {
        var attempts = 0;
        final client = MockClient((_) async {
          attempts++;
          return http.Response(response.$2, response.$1);
        });
        await expectLater(
            route.value(client),
            throwsA(isA<FirebaseFunctionsException>().having((e) => e.code,
                'status', response.$3.toLowerCase().replaceAll('_', '-'))));
        expect(attempts, 1,
            reason: 'An unconfirmed write must not be replayed.');
      });
    }
    test('${route.key} maps an interrupted connection', () async {
      var attempts = 0;
      final client = MockClient((_) async {
        attempts++;
        throw http.ClientException('internal transport details');
      });
      await expectLater(
          route.value(client),
          throwsA(isA<FirebaseFunctionsException>()
              .having((e) => e.code, 'status', 'unavailable')
              .having((e) => e.message, 'message',
                  isNot(contains('internal transport details')))));
      expect(attempts, 1);
    });
    testWidgets('${route.key} bounds a request that never completes',
        (tester) async {
      var attempts = 0;
      final pending = Completer<http.Response>();
      final client = MockClient((_) {
        attempts++;
        return pending.future;
      });
      final check = expectLater(
          route.value(client),
          throwsA(isA<FirebaseFunctionsException>()
              .having((e) => e.code, 'status', 'deadline-exceeded')));
      await tester.pump(const Duration(seconds: 31));
      await check;
      expect(attempts, 1);
      pending.complete(
          http.Response(jsonEncode({'result': validResults[route.key]}), 200));
      await tester.pump();
    });
    test('${route.key} preserves a valid confirmation', () async {
      final client = MockClient((_) async =>
          http.Response(jsonEncode({'result': validResults[route.key]}), 200));
      expect(await route.value(client), validResults[route.key]);
    });
  }
  final contracts = <String, List<Map<String, dynamic>>>{
    'updateRiderProfile': [
      {'ok': true}
    ],
    'advanceRiderOnboarding': [
      {'ok': true, 'onboardingStatus': 'profile_started'}
    ],
    'submitRiderApplication': [
      {'applicationId': 'r1', 'status': 'submitted'},
      {'applicationId': 'r1', 'status': 'suspended', 'idempotent': true},
    ],
    'sendCircumVerificationEmail': [
      {'ok': true, 'queued': true},
      {'ok': true, 'alreadyVerified': true},
    ],
    'completeDelivery': [
      {'status': 'delivered'},
      {'status': 'completed', 'idempotent': true}
    ],
    'acceptRideRequests': [
      {'status': 'accepted'}
    ],
    'updateDeliveryTrackingStatus': [
      {'status': 'navigating_to_pickup'},
      {'status': 'settlement_pending'},
      {'status': 'issue_reported'},
      {'status': 'cancelled'},
    ],
    'recordRiderArrival': [
      {
        'success': true,
        'decision': {'state': 'arrived_at_dropoff'}
      },
      {
        'success': false,
        'decision': {'riderMessage': 'Not close enough'}
      },
    ],
    'updateDeliveryLiveLocation': [
      {'success': true, 'ignored': true}
    ],
    'goOnline': [
      {'success': true, 'dispatchEligible': false, 'presence': {}}
    ],
    'goOffline': [
      {'success': true, 'presence': {}}
    ],
    'updateRiderPresence': [
      {'success': true, 'presence': {}}
    ],
    'getAvailableRequests': [
      {'eligible': false, 'nearestRequests': []},
      {
        'eligible': true,
        'nearestRequests': [
          {'requestId': 'r1'}
        ]
      },
    ],
  };
  for (final contract in contracts.entries) {
    for (final result in contract.value) {
      test('${contract.key} accepts documented outcome $result', () {
        expect(
            decodeRiderMapResponse(
                http.Response(jsonEncode({'result': result}), 200),
                operation: contract.key),
            result);
      });
    }
    for (final invalid in <Map<String, dynamic>>[
      {},
      {'unrelated': true},
      {'ok': false},
      {
        'ok': 'true',
        'success': 'true',
        'status': 'unknown',
        'onboardingStatus': 'unknown',
        'applicationId': '',
        'eligible': 'true',
        'nearestRequests': {}
      },
    ]) {
      test('${contract.key} rejects unconfirmed outcome $invalid', () {
        expect(
            () => decodeRiderMapResponse(
                http.Response(jsonEncode({'result': invalid}), 200),
                operation: contract.key),
            throwsA(isA<FirebaseFunctionsException>()));
      });
    }
  }
  test('arrival rejects a success with no confirmed state', () {
    expect(
        () => decodeRiderMapResponse(
            http.Response('{"result":{"success":true,"decision":{}}}', 200),
            operation: 'recordRiderArrival'),
        throwsA(isA<FirebaseFunctionsException>()));
  });
  test('completion rejects a nonterminal delivery state', () async {
    var attempts = 0;
    final client = MockClient((_) async {
      attempts++;
      return http.Response('{"result":{"status":"accepted"}}', 200);
    });
    await expectLater(
        invokeRiderDeliveryAuthorityWithTokens(
            'completeDelivery', const {'deliveryId': 'd1'},
            idToken: 'auth', appCheckToken: 'check', client: client),
        throwsA(isA<FirebaseFunctionsException>()));
    expect(attempts, 1);
  });
}
