import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'review entry is backend-verified and isolated from production tracking',
    () {
      final dashboard = File(
        'lib/app/rider_shell/rider_dashboard_view.dart',
      ).readAsStringSync();
      final app = File('lib/app.dart').readAsStringSync();
      final service = File(
        'lib/app/review/rider_review_fixture_service.dart',
      ).readAsStringSync();
      final screen = File(
        'lib/app/review/rider_review_fixture_screen.dart',
      ).readAsStringSync();
      final nav = File(
        'lib/app/bottom_nav/view/app_nav.dart',
      ).readAsStringSync();

      expect(service, contains("getGooglePlayReviewFixture"));
      expect(app, contains('RiderReviewFixtureService().getOwnFixture()'));
      expect(app, contains('reviewAccess ||'));
      expect(app, contains('AppNavView(reviewFixture: reviewFixture)'));
      expect(app, isNot(contains('RiderReviewFixtureScreen')));
      expect(app, contains('Any failure falls'));
      expect(dashboard, contains('RiderReviewFixtureService'));
      expect(dashboard, contains('Review location tracking'));
      expect(dashboard, contains('RiderReviewFixtureScreen'));
      expect(service, contains('setGooglePlayReviewPresence'));
      expect(nav, contains('No available deliveries'));
      expect(nav, contains('No scheduled deliveries'));
      expect(nav, contains('No review earnings'));
      expect(nav, contains('RiderReviewFixtureService().setPresence'));
      expect(nav, isNot(contains("collection('deliveryRequests')")));
      expect(dashboard, contains('widget.reviewFixture != null'));
      expect(dashboard, contains('eligibleOffers: const []'));
      expect(dashboard, contains('hasDataError: false'));
      expect(screen, contains('RiderLocationDisclosureDialog.show(context)'));
      expect(screen, contains('Geolocator.requestPermission()'));
      expect(screen, isNot(contains('updateDeliveryLiveLocation')));
      expect(screen, isNot(contains("deliveryRequests")));
    },
  );

  test('ordinary Rider availability and account gates remain production-owned',
      () {
    final app = File('lib/app.dart').readAsStringSync();
    final nav = File('lib/app/bottom_nav/view/app_nav.dart').readAsStringSync();
    final home = File('lib/app/home/bloc/home_bloc.dart').readAsStringSync();

    for (final state in [
      'onboardingNotStarted',
      'pendingReview',
      'moreInformationRequired',
      'rejected',
      'suspended',
      'frozen',
      'closed',
    ]) {
      expect(app, contains('RiderAccountState.$state'));
    }
    expect(nav, contains('const _CentralAction()'));
    expect(home, contains("httpsCallable('goOnline')"));
    expect(home, contains("httpsCallable('goOffline')"));
    expect(home, contains('RiderAccountStateResolver.canOperate'));
  });
}
