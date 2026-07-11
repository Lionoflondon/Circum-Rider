import 'dart:io';

import 'package:circum_rider/app/rider_design/rider_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonical Rider presentation replacement', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final nav = File('lib/app/bottom_nav/view/app_nav.dart').readAsStringSync();
    final dashboard = File('lib/app/rider_shell/rider_dashboard_view.dart')
        .readAsStringSync();
    final profile =
        File('lib/app/rider_shell/rider_profile_view.dart').readAsStringSync();
    final schedule =
        File('lib/app/schedule/rider_schedule_view.dart').readAsStringSync();
    final earnings =
        File('lib/app/account/view/earnings.dart').readAsStringSync();
    final accountBloc =
        File('lib/app/account/bloc/account_bloc.dart').readAsStringSync();
    final offers = File('lib/app/rider_jobs/rider_job_offer_screen.dart')
        .readAsStringSync();

    test('old four-tab shell is gone', () {
      expect(
          nav, contains("['Home', 'Jobs', 'Schedule', 'Earnings', 'Profile']"));
      expect(nav, isNot(contains("label: 'History'")));
      expect(nav, isNot(contains("label: 'Live Chat'")));
      expect(nav, isNot(contains("label: 'Account'")));
      expect(nav, isNot(contains('HomeView()')));
      expect(nav, isNot(contains('SupportView')));
      expect(nav, isNot(contains('AccountView')));
    });

    test('legacy primary presentation files are retired', () {
      expect(File('lib/app/home/view/home.dart').existsSync(), isFalse);
      expect(File('lib/app/account/view/account.dart').existsSync(), isFalse);
      expect(File('lib/app/account/view/earnings_chart.dart').existsSync(),
          isFalse);
      expect(
          File('lib/app/account/view/bottom_sheets/withdrawal_bs.dart')
              .existsSync(),
          isFalse);
    });

    test('production mock preview route is absent', () {
      expect(mainSource, isNot(contains('/rider/jobs/offers/preview')));
      expect(mainSource, isNot(contains('previewOffers:')));
      expect(mainSource, isNot(contains('textScaleFactor: 1.0')));
    });

    test('home is compact, backend driven and operational', () {
      expect(dashboard, contains("collection('riderProfiles')"));
      expect(dashboard, contains("collection('riderEarnings')"));
      expect(dashboard, contains("collection('deliveryRequests')"));
      expect(dashboard, contains('Good '));
      expect(dashboard, contains('Go Online'));
      expect(dashboard, contains('Priority operations'));
      expect(dashboard, contains('Upcoming schedule'));
      expect(dashboard, contains('Recent activity'));
    });

    test('jobs expose Taken state and scheduled handoff', () {
      expect(offers, contains('Job no longer available'));
      expect(offers, contains('Back to job feed'));
      expect(offers, contains('RiderAcceptStatus.alreadyTaken'));
      expect(offers, contains('onScheduledAccepted'));
      expect(offers, isNot(contains("label: 'Reject'")));
    });

    test('schedule and earnings consume canonical records', () {
      expect(schedule, contains("collection('deliveryRequests')"));
      expect(schedule, contains('assignedRider'));
      expect(schedule,
          anyOf(contains('expected earnings'), contains('riderEarning')));
      expect(earnings, contains("collection('riderEarnings')"));
      expect(earnings, contains("collection('payoutRequests')"));
      expect(earnings, contains("collection('riderWalletTransactions')"));
      expect(accountBloc, contains('requestRiderWithdrawal'));
      expect(earnings, contains('Roth remains separate'));
    });

    test('profile is the Rider Operations & Account hub', () {
      expect(profile, contains('Operations & Account'));
      expect(profile, contains('Ready to work'));
      expect(profile, contains('Work preferences'));
      expect(profile, contains('Vehicles'));
      expect(profile, contains('Documents'));
      expect(profile, contains('App permissions'));
      expect(profile, contains('Safety & support'));
      expect(profile, contains('Performance'));
      expect(profile, contains('Earnings and payouts'));
      expect(profile, contains('Account and legal'));
      expect(profile, contains('RiderGlassSurface'));
    });

    test('profile supports readiness, protected fields and vehicles', () {
      expect(profile, contains('RiderReadinessSnapshot'));
      expect(profile, contains('RiderAccountStateResolver.resolveRecords'));
      expect(profile, contains('RiderRankProgress'));
      expect(profile, contains('rawVehicles.take(2)'));
      expect(profile, contains('rank'));
      expect(profile, contains('trustPoints'));
      expect(profile, isNot(contains('updateRank')));
      expect(profile, isNot(contains('updateTrust')));
      expect(profile, isNot(contains('approvalStatus\':')));
    });

    test('profile keeps existing contextual routes and adds permissions', () {
      expect(profile, contains('RiderNotificationsView'));
      expect(profile, contains('HistoryView'));
      expect(profile, contains('SupportView'));
      expect(profile, contains('Permission.notification'));
      expect(profile, contains('Permission.camera'));
      expect(profile, contains('Geolocator.checkPermission'));
      expect(profile, contains('backgroundLocation'));
    });

    test('profile persists work preferences without duplicating protected data',
        () {
      expect(profile, contains("collection('riderProfiles')"));
      expect(profile, contains('workPreferences.'));
      expect(profile, contains('Preferred working areas'));
      expect(profile, contains('Health+'));
      expect(profile, contains('Vanguard'));
      expect(profile, contains('Heavy Duty'));
      expect(profile, contains('\$label delivery preference'));
    });

    test('profile earnings shortcuts avoid rider-facing tax language', () {
      expect(profile, contains('Available earnings'));
      expect(profile, contains('pending earnings'));
      expect(profile, contains('Payout history'));
      expect(profile, contains('Payout status'));
      expect(profile, contains('Transaction history'));
      expect(profile.toLowerCase(), isNot(contains('hmrc')));
      expect(profile.toLowerCase(), isNot(contains('tax advice')));
      expect(profile.toLowerCase(), isNot(contains('tax filing')));
    });
  });

  testWidgets('web preview remains a centred mobile-first surface',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(
      home: RiderMobileFrame(child: SizedBox.expand()),
    ));
    final box = tester.renderObject<RenderBox>(find.byType(ColoredBox).last);
    expect(box.size.width, lessThanOrEqualTo(520));
  });

  testWidgets('rank display follows the canonical order', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: RiderRankProgress(rank: 'Warden', trustPoints: 420),
      ),
    ));
    expect(find.text('WARDEN'), findsOneWidget);
    expect(find.text('420 TRUST'), findsOneWidget);
    expect(find.textContaining('Knight'), findsOneWidget);
  });
}
