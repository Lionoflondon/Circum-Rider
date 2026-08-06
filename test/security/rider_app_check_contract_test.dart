import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider App Check is initialized for mobile and web startup', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final webMain = File('lib/main_rider_web.dart').readAsStringSync();
    final mobileWorkflow =
        File('.github/workflows/rc1_release_build.yml').readAsStringSync();
    final webBuild = File('scripts/build_rider_web.sh').readAsStringSync();
    final appCheck =
        File('lib/app/security/rider_app_check.dart').readAsStringSync();

    expect(pubspec, contains('firebase_app_check:'));
    expect(main, contains('initializeRiderAppCheck'));
    expect(main, contains('RiderStartupBlocked'));
    expect(main, contains('if (kIsWeb)'));
    expect(main, contains('await Firebase.initializeApp();'));
    expect(main, isNot(contains('DefaultFirebaseOptions.web')));
    expect(main, isNot(contains('RiderWebStartupApp')));
    expect(webMain, contains('DefaultFirebaseOptions.web'));
    expect(webMain, contains('RiderWebStartupApp'));
    expect(webMain, contains('initializeRiderAppCheck'));
    expect(webMain, isNot(contains('await Firebase.initializeApp();')));
    expect(mobileWorkflow, contains('--target=lib/main.dart'));
    expect(webBuild, contains('--target=lib/main_rider_web.dart'));
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

    final gradle = File('android/app/build.gradle').readAsStringSync();
    expect(gradle, contains("System.getenv('GOOGLE_MAPS_API_KEY')"));
    expect(
        gradle, contains("localProperties.getProperty('GOOGLE_MAPS_API_KEY')"));
    expect(gradle, contains('throw new GradleException'));
    expect(gradle, contains('manifestPlaceholders["googleMapsApiKey"]'));
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
