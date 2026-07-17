import 'dart:io';

import 'package:circum_rider/app/security/rider_app_check.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider App Check provider policy is release-safe', () {
    expect(
      riderAndroidAppCheckProvider(debug: true),
      AndroidProvider.debug,
    );
    expect(
      riderAndroidAppCheckProvider(debug: false),
      AndroidProvider.playIntegrity,
    );
    expect(
      riderAppleAppCheckProvider(debug: true),
      AppleProvider.debug,
    );
    expect(
      riderAppleAppCheckProvider(debug: false),
      AppleProvider.appAttestWithDeviceCheckFallback,
    );
  });

  test('Rider web App Check requires an explicit Enterprise site key', () {
    expect(
      riderWebAppCheckProvider(isWeb: true, siteKey: ''),
      isNull,
    );
    expect(
      riderWebAppCheckProvider(isWeb: false, siteKey: ''),
      isNull,
    );
    expect(
      riderWebAppCheckProvider(isWeb: true, siteKey: 'site-key'),
      isA<ReCaptchaEnterpriseProvider>(),
    );
  });

  test('Rider startup initializes App Check before sensitive Firebase services',
      () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final firebaseInit = mainSource.indexOf('Firebase.initializeApp');
    final appCheckInit = mainSource.indexOf('initializeRiderAppCheck');
    final messagingUse = mainSource.indexOf('FirebaseMessaging.instance');

    expect(firebaseInit, isNonNegative);
    expect(appCheckInit, greaterThan(firebaseInit));
    expect(messagingUse, greaterThan(appCheckInit));
    expect(mainSource, contains('RiderStartupBlocked'));
  });

  test('Rider App Check source never logs or stores App Check token values',
      () {
    final source =
        File('lib/app/security/rider_app_check.dart').readAsStringSync();
    final executableLines = source
        .split('\n')
        .map((line) => line.trimLeft())
        .where((line) => !line.startsWith('//'))
        .join('\n');

    expect(executableLines, isNot(contains('print(')));
    expect(executableLines, isNot(contains('debugPrint(')));
    expect(executableLines, isNot(contains('getToken(')));
    expect(
        executableLines, isNot(contains('setTokenAutoRefreshEnabled(false)')));
  });
}
