import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider App Check is initialized for mobile and web startup', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final webMain = File('lib/main_rider_web.dart').readAsStringSync();
    final appCheck =
        File('lib/app/security/rider_app_check.dart').readAsStringSync();

    expect(pubspec, contains('firebase_app_check:'));
    expect(main, contains('initializeRiderAppCheck'));
    expect(main, contains('RiderStartupBlocked'));
    expect(main, contains('DefaultFirebaseOptions.web'));
    expect(main, isNot(contains('RiderWebStartupApp')));
    expect(webMain, contains('DefaultFirebaseOptions.web'));
    expect(webMain, contains('RiderWebStartupApp'));
    expect(webMain, contains('initializeRiderAppCheck'));
    expect(appCheck, contains('AndroidProvider.playIntegrity'));
    expect(appCheck, contains('AppleProvider.appAttest'));
    expect(appCheck, contains('ReCaptchaEnterpriseProvider'));
    expect(appCheck, contains('RIDER_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY'));
    expect(
        appCheck, isNot(contains('CIRCUM_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY')));
    expect(appCheck, isNot(contains('debugProvider')));
  });

  test('Rider runtime Maps keys are provided by configuration', () {
    final hardcodedMapsKey = RegExp(r'AIza[0-9A-Za-z_-]+');
    for (final path in [
      'android/app/src/main/AndroidManifest.xml',
      'ios/Runner/AppDelegate.swift',
      'ios/Runner/Info.plist',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(matches(hardcodedMapsKey)), reason: path);
    }

    expect(
      File('android/app/build.gradle').readAsStringSync(),
      contains('GOOGLE_MAPS_API_KEY'),
    );
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains(r'${googleMapsApiKey}'),
    );
    expect(
      File('ios/Runner/Info.plist').readAsStringSync(),
      contains(r'$(GOOGLE_MAPS_API_KEY)'),
    );
    expect(
      File('.github/workflows/rc1_release_build.yml').readAsStringSync(),
      contains('RIDER_ANDROID_GOOGLE_MAPS_API_KEY'),
    );
    expect(
      File('.github/workflows/rc1_release_build.yml').readAsStringSync(),
      contains('GOOGLE_MAPS_DIRECTIONS_API_KEY'),
    );
    expect(
      File('lib/app/home/bloc/home_bloc.dart').readAsStringSync(),
      contains("String.fromEnvironment('GOOGLE_MAPS_DIRECTIONS_API_KEY')"),
    );
    expect(
      File('lib/app/home/repo/direction_service.dart').readAsStringSync(),
      contains("String.fromEnvironment('GOOGLE_MAPS_DIRECTIONS_API_KEY')"),
    );
  });
}
