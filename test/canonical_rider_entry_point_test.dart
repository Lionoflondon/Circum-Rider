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

    test('uses the auth session gate and one authenticated app shell', () {
      expect(appSource, contains('child: OnboardingView()'));
      expect(appSource, isNot(contains('AddDetailsView')));
      expect(appSource, contains('AppNavView(reviewFixture: reviewFixture)'));
      expect(appSource, isNot(contains('RiderAccountStatusView')));
      expect(appSource, isNot(contains('state.riderAccountState ==')));
    });
  });
}
