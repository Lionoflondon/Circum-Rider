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
      expect(app, contains('AppNavView(reviewFixture: reviewFixture)'));
      expect(app, isNot(contains('RiderReviewFixtureScreen')));
      expect(app, contains('Any failure falls'));
      expect(dashboard, contains('RiderReviewFixtureService'));
      expect(dashboard, contains('Review location tracking'));
      expect(dashboard, contains('RiderReviewFixtureScreen'));
      expect(service, contains('setGooglePlayReviewPresence'));
      expect(nav, contains('No scheduled deliveries'));
      expect(nav, contains('isolatedEmptyData: _isReviewer'));
      expect(nav, contains('isolatedZeroData: _isReviewer'));
      expect(nav, isNot(contains('No available deliveries')));
      expect(nav, isNot(contains('No review earnings')));
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

    expect(app, contains('if (state.currentState == AppState.authenticated)'));
    expect(app, isNot(contains('state.riderAccountState ==')));
    expect(nav, contains('const _CentralAction()'));
    expect(home, contains("httpsCallable('goOnline')"));
    expect(home, contains("httpsCallable('goOffline')"));
    expect(home, contains('RiderAccountStateResolver.canOperate'));
  });

  test('reviewer Jobs uses the production screen with an isolated empty source',
      () {
    final nav = File('lib/app/bottom_nav/view/app_nav.dart').readAsStringSync();
    final jobs = File(
      'lib/app/rider_jobs/rider_job_offer_screen.dart',
    ).readAsStringSync();

    expect(nav, contains('RiderJobOfferScreen('));
    expect(nav, contains('isolatedEmptyData: _isReviewer'));
    expect(jobs, contains('if (widget.isolatedEmptyData)'));
    expect(jobs, contains("title: 'No offers nearby'"));
    expect(jobs, contains("title: 'Available deliveries'"));
    expect(jobs, contains("title: 'Scheduled deliveries'"));
    expect(jobs, contains("title: 'Active delivery'"));
    expect(jobs, contains("title: 'Activity'"));
    expect(
      jobs.indexOf('if (widget.isolatedEmptyData)'),
      lessThan(jobs.indexOf("collection('deliveryRequests')")),
    );
  });

  test('reviewer Earnings uses production sections with isolated zero data',
      () {
    final nav = File('lib/app/bottom_nav/view/app_nav.dart').readAsStringSync();
    final earnings = File(
      'lib/app/account/view/earnings.dart',
    ).readAsStringSync();

    expect(nav, contains('EarningsView('));
    expect(nav, contains('isolatedZeroData: _isReviewer'));
    expect(earnings, contains('if (widget.isolatedZeroData) return;'));
    expect(earnings, contains("'storedAvailable': 0"));
    expect(earnings, contains("'pending': 0"));
    expect(earnings, contains("'activityCount': 0"));
    expect(earnings, contains('showZeroValueSections: true'));
    expect(earnings, contains("'Available balance'"));
    expect(earnings, contains("title: 'Payout history'"));
    expect(earnings, contains("title: 'Transactions'"));
    expect(
      earnings.indexOf('if (widget.isolatedZeroData) return;'),
      lessThan(earnings.indexOf("httpsCallable('getRiderEarningsSummary')")),
    );
  });
}
