import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonical Rider jobs navigation', () {
    final nav = File('lib/app/bottom_nav/view/app_nav.dart').readAsStringSync();
    final dashboard = File('lib/app/rider_shell/rider_dashboard_view.dart')
        .readAsStringSync();
    final offers = File('lib/app/rider_jobs/rider_job_offer_screen.dart')
        .readAsStringSync();
    final offerCard =
        File('lib/app/rider_jobs/rider_offer_card.dart').readAsStringSync();

    test('shell primary jobs entries resolve to the swipeable offer stack', () {
      expect(nav, contains('RiderJobOfferScreen('));
      expect(nav, contains('_CentralAction(onTap: () => onSelect(1))'));
      expect(nav, contains("label: 'Open delivery offers'"));
      expect(nav, contains("label: 'Jobs'"));
      expect(nav, contains('onTap: () => onSelect(1)'));
      expect(nav, contains('onScheduledAccepted: () => select(2)'));
      expect(nav, isNot(contains('MarketplaceView')));
      expect(nav, isNot(contains('RiderMarketplace')));
    });

    test('dashboard jobs cards and quick action open the same jobs destination',
        () {
      expect(dashboard, contains('Priority operations'));
      expect(dashboard, contains('onAction: () => onSelectTab(1)'));
      expect(dashboard, contains('onTap: () => onSelectTab(1)'));
      expect(dashboard, contains("label: 'Jobs'"));
      expect(dashboard, contains("where('status', isEqualTo: 'requested')"));
      expect(dashboard, contains('Open delivery offers'));
      expect(dashboard, isNot(contains('Open the marketplace')));
      expect(dashboard, isNot(contains('MarketplaceView')));
      expect(dashboard, isNot(contains('GenericJobList')));
    });

    test('jobs destination remains the approved swipeable offer card flow', () {
      expect(offers, contains('class RiderJobOfferScreen'));
      expect(offers, contains("static const routeName = '/rider/jobs/offers'"));
      expect(offers, contains('RiderOfferStack'));
      expect(offers, contains("import 'rider_offer_card.dart'"));
      expect(offerCard, contains('Accept Delivery'));
      expect(offers, contains("where('status', isEqualTo: 'requested')"));
      expect(offers, contains('No offers nearby'));
      expect(offers, contains('RiderAcceptStatus.alreadyTaken'));
      expect(offers, contains('Job no longer available'));
      expect(offers, contains('Back to job feed'));
      expect(offers, contains('onScheduledAccepted'));
      expect('$offers\n$offerCard', isNot(contains("label: 'Reject'")));
      expect('$offers\n$offerCard', isNot(contains("label: 'Decline'")));
    });
  });
}
