import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final onboarding =
      File('lib/app/onboarding/view/onboarding.dart').readAsStringSync();
  final reviewService = File('lib/app/review/rider_review_fixture_service.dart')
      .readAsStringSync();
  final reviewScreen = File('lib/app/review/rider_review_fixture_screen.dart')
      .readAsStringSync();

  test('ordinary Rider signup has no UK work declaration or assertion', () {
    expect(onboarding,
        isNot(contains('I confirm I am legally entitled to work in the UK.')));
    expect(onboarding, isNot(contains('_rightToWork')));
    expect(onboarding, isNot(contains('workEntitledUk')));
  });

  test('reviewer provisioning occurs before signup and uses server authority',
      () {
    expect(onboarding, isNot(contains('skipWorkEligibility')));
    expect(onboarding, isNot(contains('google_play_review')));
    expect(reviewService, contains("getGooglePlayReviewFixture"));
    expect(
        reviewScreen, contains('RiderLocationDisclosureDialog.show(context)'));
  });
}
