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
          nav, contains("['Home', 'Jobs', 'Action', 'Earnings', 'Profile']"));
      expect(nav, contains('const _CentralAction()'));
      expect(nav, contains('_showAvailabilitySheet'));
      expect(nav, contains('SetRideStatus('));
      expect(nav, isNot(contains('_CentralAction(onTap: () => onSelect(1))')));
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
      expect(dashboard, contains("where('status', isEqualTo: 'requested')"));
      expect(dashboard, contains('Good '));
      expect(dashboard, contains('Go online'));
      expect(dashboard, contains('Priority operations'));
      expect(dashboard, contains('Upcoming schedule'));
      expect(dashboard, contains('Recent activity'));
      expect(dashboard, contains('CIRCUM RIDER'));
      expect(dashboard, contains('No eligible jobs'));
      expect(dashboard, contains('No scheduled deliveries'));
      expect(dashboard, contains('Open delivery offers'));
      expect(dashboard, isNot(contains('Open the marketplace')));
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
      expect(schedule, contains('_ScheduleFilter'));
      expect(schedule, contains("'All'"));
      expect(schedule, contains("'Today'"));
      expect(schedule, contains("'This week'"));
      expect(schedule, contains("'Vanguard'"));
      expect(schedule, contains('_DayGroup'));
      expect(schedule, contains('Ready to start'));
      expect(schedule, contains('Starts in'));
      expect(schedule, contains('Gifts by CIRCUM'));
      expect(schedule, contains('Health+'));
      expect(schedule, contains('RiderGlassSurface'));
      expect(earnings, contains('getRiderEarningsSummary'));
      expect(earnings, contains("collection('riderEarnings')"));
      expect(earnings, contains("collection('payoutRequests')"));
      expect(earnings, contains("collection('riderWalletTransactions')"));
      expect(accountBloc, contains('requestRiderWithdrawal'));
      expect(earnings, contains('Roth remains separate'));
      expect(earnings, contains('CASH EARNINGS'));
      expect(earnings, contains('Available to withdraw'));
      expect(earnings, contains('Payout history'));
      expect(earnings, contains('Earnings activity'));
      expect(earnings, contains('WAITING / NO-SHOW'));
      expect(earnings, contains('Adjustment Credit'));
      expect(earnings, contains('Adjustment Debit'));
      expect(earnings, contains('Withdrawal processing'));
      expect(earnings, contains('Withdrawal failed'));
      expect(earnings, contains('Review required'));
      expect(earnings, isNot(contains('£284.60')));
      expect(earnings, isNot(contains('£238.40')));
      expect(earnings, isNot(contains('£120.00')));
      expect(earnings, isNot(contains('08/07/2026')));
      expect(earnings, isNot(contains('Marketplace · Camden to Islington')));
      expect(earnings, isNot(contains('v2.4.1')));
      expect(earnings, isNot(contains('Roth withdrawal')));
      expect(earnings, isNot(contains('Paid to Wallet')));
    });

    test('rider glass is restrained rather than excessive', () {
      final riderUi =
          File('lib/app/rider_design/rider_ui.dart').readAsStringSync();
      expect(riderUi, contains('this.blur = 10'));
      expect(riderUi, contains('blur.clamp(0, 12)'));
      expect(riderUi, contains('withValues(alpha: .07)'));
      expect(riderUi, isNot(contains('blurRadius: 34')));
    });

    test('profile tab hosts the canonical Rider Options screen', () {
      expect(profile, contains("'Options'"));
      expect(profile, contains('Personal details'));
      expect(profile, contains('Documents & verification'));
      expect(profile, contains('Delivery activity'));
      expect(profile, contains('Notifications'));
      expect(profile, contains('Location sharing'));
      expect(profile, contains('Support'));
      expect(profile, contains('Legal'));
      expect(profile, contains('Privacy'));
      expect(profile, contains('Terms'));
      expect(profile, contains('Rider agreement'));
      expect(profile, contains('Licences and notices'));
      expect(profile, contains('Sign out'));
      expect(profile, contains('_OptionsScreen'));
      expect(profile, contains('_IdentityCard'));
      expect(profile, contains('Geolocator.checkPermission'));
      expect(profile, contains('Permission.notification'));
      expect(profile, isNot(contains('Operations & Account')));
      expect(profile, isNot(contains('Ready to work')));
      expect(profile, isNot(contains('Work preferences')));
      expect(profile, isNot(contains('App permissions')));
      expect(profile, isNot(contains('Performance')));
      expect(profile, isNot(contains('Earnings and payouts')));
      expect(profile, isNot(contains('Account milestones')));
      expect(profile, isNot(contains('RiderStatusBadge')));
      expect(profile, isNot(contains('RiderMetric')));
      expect(profile, isNot(contains('SwitchListTile')));
      expect(profile, isNot(contains('Jason Adesanya')));
      expect(profile, isNot(contains('WARDEN · 412 TRUST')));
      expect(profile, isNot(contains('Verified Rider')));
      expect(profile, isNot(contains('payouts')));
    });

    test('profile keeps protected fields read only and routes to details', () {
      expect(profile, contains('RiderAccountStateResolver.resolveRecords'));
      expect(profile, contains('RiderRankSnapshot.from'));
      expect(profile, contains('rank'));
      expect(profile, contains('trustPoints'));
      expect(profile, contains('VerificationView'));
      expect(profile, contains('AccountDetails'));
      expect(profile, contains('HistoryView'));
      expect(profile, isNot(contains('updateRank')));
      expect(profile, isNot(contains('updateTrust')));
      expect(profile, isNot(contains('approvalStatus\':')));
    });

    test('options keeps existing contextual routes and live permission states',
        () {
      expect(profile, contains('RiderNotificationsView'));
      expect(profile, contains('SupportView'));
      expect(profile, contains("collection('riderProfiles')"));
      expect(profile, contains("collection('riders')"));
      expect(profile, contains('RiderLegalView'));
      expect(profile, contains('Geolocator.openAppSettings'));
      expect(profile, contains('showModalBottomSheet'));
      expect(profile, contains('SignOut()'));
      expect(profile, isNot(contains('Permission.camera')));
      expect(profile, isNot(contains('backgroundLocation')));
    });

    test('profile avoids dashboard and rider-facing tax language', () {
      expect(profile, isNot(contains('Available earnings')));
      expect(profile, isNot(contains('pending earnings')));
      expect(profile, isNot(contains('Payout history')));
      expect(profile, isNot(contains('Payout status')));
      expect(profile, isNot(contains('Transaction history')));
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
