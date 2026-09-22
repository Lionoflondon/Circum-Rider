import 'dart:convert';
import 'dart:io';

import 'package:circum_rider/app/account_bootstrap_api.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'Rider profile update preserves callable auth, App Check, and envelope',
    () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'result': {'ok': true, 'riderId': 'rider-1'},
          }),
          200,
        );
      });

      final result = await invokeRiderProfileUpdateViaCloudRun(
        const {'fullName': 'Rider', 'section': 'profile_details'},
        idToken: 'id-token',
        appCheckToken: 'app-check-token',
        client: client,
      );

      expect(captured.method, 'POST');
      expect(captured.url.host, contains('circum-account-bootstrap'));
      expect(captured.url.path, '/updateRiderProfile');
      expect(captured.headers['authorization'], 'Bearer id-token');
      expect(captured.headers['x-firebase-appcheck'], 'app-check-token');
      expect(jsonDecode(captured.body), {
        'data': {'fullName': 'Rider', 'section': 'profile_details'},
      });
      expect(result, {'ok': true, 'riderId': 'rider-1'});
    },
  );

  test('Cloud Run errors retain callable status and message', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'error': {
            'status': 'PERMISSION_DENIED',
            'message': 'This account cannot change that profile.',
          },
        }),
        403,
      ),
    );

    await expectLater(
      invokeRiderProfileUpdateViaCloudRun(
        const {},
        idToken: 'id-token',
        appCheckToken: 'app-check-token',
        client: client,
      ),
      throwsA(
        isA<FirebaseFunctionsException>()
            .having((error) => error.code, 'code', 'permission-denied')
            .having(
              (error) => error.message,
              'message',
              'This account cannot change that profile.',
            ),
      ),
    );
  });

  test('Rider application submission uses the authenticated Cloud Run route',
      () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'result': {'applicationId': 'rider-1', 'status': 'submitted'},
        }),
        200,
      );
    });

    final result = await invokeSubmitRiderApplicationViaCloudRun(
      const {'idempotencyKey': 'rider_application:rider-1'},
      idToken: 'id-token',
      appCheckToken: 'app-check-token',
      client: client,
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/submitRiderApplication');
    expect(captured.headers['authorization'], 'Bearer id-token');
    expect(captured.headers['x-firebase-appcheck'], 'app-check-token');
    expect(jsonDecode(captured.body), {
      'data': {'idempotencyKey': 'rider_application:rider-1'},
    });
    expect(result, {'applicationId': 'rider-1', 'status': 'submitted'});
  });

  test('all active Rider profile callers use the shared Cloud Run client', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in sources) {
      expect(
        file.readAsStringSync(),
        isNot(contains("httpsCallable('updateRiderProfile')")),
        reason: file.path,
      );
    }
    for (final path in [
      'lib/app/authentication/bloc/auth_bloc.dart',
      'lib/app/onboarding/rider_application_centre.dart',
      'lib/app/rider_shell/rider_profile_details_view.dart',
      'lib/app/rider_shell/rider_vehicle_updates.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('updateRiderProfileViaCloudRun'), reason: path);
      expect(
        source,
        isNot(contains("httpsCallable('updateRiderProfile')")),
        reason: path,
      );
    }
  });

  test('shared client obtains Auth and required App Check tokens', () {
    final source = File(
      'lib/app/account_bootstrap_api.dart',
    ).readAsStringSync();
    expect(source, contains('user?.getIdToken()'));
    expect(source, contains('FirebaseAppCheck.instance'));
    expect(source, contains('.getToken()'));
    expect(source, contains(r"'authorization': 'Bearer $idToken'"));
    expect(source, contains("'x-firebase-appcheck': appCheckToken"));
  });
}
