import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonical Rider application entry point', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final appSource = File('lib/app.dart').readAsStringSync();

    test('launches the committed CircumRider root', () {
      expect(mainSource, contains('appBuilder: (_) => const CircumRider()'));
      expect(mainSource, isNot(contains('CanonicalRiderApp')));
      expect(mainSource, isNot(contains("import 'canonical_rider/")));
    });

    test('uses the existing auth session gate and onboarding routes', () {
      expect(appSource, contains('child: OnboardingView()'));
      expect(appSource, contains('child: RiderApplicationCentre()'));
      expect(appSource, isNot(contains('AddDetailsView')));
      expect(appSource, contains('child: ApplicationSubmittedView()'));
      expect(appSource, contains('AppNavView(reviewFixture: reviewFixture)'));
    });
  });
}
