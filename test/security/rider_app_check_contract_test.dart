import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider App Check is initialized for mobile and web startup', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final appCheck =
        File('lib/app/security/rider_app_check.dart').readAsStringSync();

    expect(pubspec, contains('firebase_app_check:'));
    expect(main, contains('initializeRiderAppCheck'));
    expect(main, contains('RiderStartupBlocked'));
    expect(appCheck, contains('AndroidProvider.playIntegrity'));
    expect(appCheck, contains('AppleProvider.appAttest'));
    expect(appCheck, contains('ReCaptchaEnterpriseProvider'));
    expect(appCheck, contains('CIRCUM_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY'));
    expect(appCheck, isNot(contains('debugProvider')));
  });
}
