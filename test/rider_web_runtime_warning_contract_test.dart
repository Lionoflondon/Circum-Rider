import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider Web verifies App Check before protected startup', () {
    final source =
        File('lib/app/security/rider_app_check.dart').readAsStringSync();

    expect(source, contains('FirebaseAppCheck.instance.getToken(true)'));
    expect(source, contains('token == null || token.trim().isEmpty'));
  });

  test('Rider Web ships its Firebase Messaging service worker', () {
    final worker = File('web/firebase-messaging-sw.js');

    expect(worker.existsSync(), isTrue);
    final source = worker.readAsStringSync();
    expect(source, contains('firebase-messaging-compat.js'));
    expect(source, contains('firebase.messaging()'));
  });

  test('canonical Earnings view does not invoke legacy HTTP earnings', () {
    final view = File('lib/app/account/view/earnings.dart').readAsStringSync();

    expect(view, isNot(contains('GetEarnings()')));
    expect(view, contains("httpsCallable('getRiderEarningsSummary')"));
  });
}
