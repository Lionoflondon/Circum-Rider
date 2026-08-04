import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonical Rider application entry point', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final appSource = File('lib/app.dart').readAsStringSync();

    test('launches the committed CircumRider root', () {
      expect(mainSource, contains('runApp(const CircumRider())'));
      expect(mainSource, isNot(contains('DefaultFirebaseOptions.web')));
      expect(mainSource, isNot(contains('RiderWebStartupApp')));
      expect(mainSource, isNot(contains('CanonicalRiderApp')));
      expect(mainSource, isNot(contains("import 'canonical_rider/")));
    });

    test('keeps Rider Web startup on a dedicated entry point', () {
      final webMain = File('lib/main_rider_web.dart').readAsStringSync();
      expect(webMain, contains('RiderWebStartupApp'));
      expect(webMain, contains('DefaultFirebaseOptions.web'));
      expect(webMain, contains('RDR-WEB-START-001'));
    });

    test('uses the existing auth session gate and onboarding routes', () {
      expect(appSource, contains('child: OnboardingView()'));
      expect(appSource, contains('child: AddDetailsView()'));
      expect(appSource, contains('child: ApplicationSubmittedView()'));
      expect(appSource, contains('MaterialPage(child: AppNavView())'));
    });
  });
}
