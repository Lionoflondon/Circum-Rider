import 'dart:io';

import 'package:circum_rider/app/rider_design/rider_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonical Rider presentation replacement', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final webIndex = File('web/index.html').readAsStringSync();
    final nav = File('lib/app/bottom_nav/view/app_nav.dart').readAsStringSync();
    final dashboard = File('lib/app/rider_shell/rider_dashboard_view.dart')
        .readAsStringSync();
    final homeBloc =
        File('lib/app/home/bloc/home_bloc.dart').readAsStringSync();
    final profile =
        File('lib/app/rider_shell/rider_profile_view.dart').readAsStringSync();
    final profileDetails =
        File('lib/app/rider_shell/rider_profile_details_view.dart')
            .readAsStringSync();
    final accessibility =
        File('lib/app/rider_shell/rider_accessibility_settings_view.dart')
            .readAsStringSync();
    final support =
        File('lib/app/support/view/support.dart').readAsStringSync();
    final verification =
        File('lib/app/verification/view/verification.dart').readAsStringSync();
    final riderTruth =
        File('lib/app/rider_truth/rider_truth.dart').readAsStringSync();
    final schedule =
        File('lib/app/schedule/rider_schedule_view.dart').readAsStringSync();
    final earnings =
        File('lib/app/account/view/earnings.dart').readAsStringSync();
    final accountBloc =
        File('lib/app/account/bloc/account_bloc.dart').readAsStringSync();
    final authBloc =
        File('lib/app/authentication/bloc/auth_bloc.dart').readAsStringSync();
    final accountDetails =
        File('lib/app/account/view/account_details.dart').readAsStringSync();
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

    test('startup uses splash hold instead of rotating boot copy', () {
      expect(mainSource, contains('_RiderSplashHold'));
      expect(mainSource, contains("AssetImage('assets/images/splash.png')"));
      expect(mainSource, isNot(contains('Starting Rider')));
      expect(mainSource, isNot(contains('CircularProgressIndicator(')));
      expect(webIndex, contains('startup-logo'));
      expect(webIndex, contains('splash/img/dark-3x.png'));
      expect(webIndex, isNot(contains('startup-spinner')));
      expect(webIndex, isNot(contains('Starting Rider')));
    });

    test('home is compact, backend driven and operational', () {
      expect(dashboard, contains("collection('riderProfiles')"));
      expect(dashboard, contains("collection('riderEarnings')"));
      expect(dashboard, contains("collection('deliveryRequests')"));
      expect(dashboard, contains('watchUnreadNotificationCount'));
      expect(dashboard, contains("where('status', isEqualTo: 'requested')"));
      expect(dashboard, contains('Good '));
      expect(dashboard, contains('Go online'));
      expect(dashboard, contains('Available deliveries'));
      expect(dashboard, contains('Upcoming schedule'));
      expect(dashboard, contains('Recent activity'));
      expect(dashboard, contains('CIRCUM RIDER'));
      expect(dashboard, contains('No deliveries available'));
      expect(dashboard, contains('New offers will appear here automatically.'));
      expect(dashboard, contains('No scheduled deliveries'));
      expect(dashboard, contains('Open delivery offers'));
      expect(dashboard, isNot(contains('Open the marketplace')));
    });

    test('home exposes internal GPS diagnostics and persistent heartbeat', () {
      expect(homeBloc, contains('_presenceHeartbeatInterval'));
      expect(homeBloc, contains('updateRiderPresence'));
      expect(homeBloc, contains("'gpsSignalQuality'"));
      expect(homeBloc, contains("'backgroundTracking'"));
      expect(dashboard, contains('_InternalDiagnosticsCard'));
      expect(dashboard, contains('Internal dispatch diagnostics'));
      expect(dashboard, contains('Dispatch eligibility'));
    });

    test('rider profile photos use the canonical identity contract', () {
      expect(authBloc, contains("rider-profiles/\${user.uid}/profile.jpg"));
      expect(authBloc, contains("rider-profiles/\${user.uid}/thumbnail.jpg"));
      expect(authBloc, contains('image_lib.copyCrop'));
      expect(authBloc, contains('image_lib.encodeJpg'));
      expect(authBloc, contains("'profilePhotoVersion'"));
      expect(authBloc, contains("'profileThumbnailUrl'"));
      expect(accountDetails, contains('image.readAsBytes()'));
      expect(accountDetails, contains('_ProfilePhotoCropDialog'));
      expect(accountDetails, contains('InteractiveViewer'));
      expect(accountDetails, contains('RepaintBoundary'));
      expect(dashboard.indexOf('profileThumbnailUrl'),
          lessThan(dashboard.indexOf('profilePhotoUrl')));
      expect(dashboard, contains('_dashboardProfileData'));
      expect(dashboard, contains('_HeaderProfilePhoto'));
      expect(dashboard, contains('Icons.person_rounded'));
      expect(dashboard, isNot(contains('_initials(rawName)')));
      expect(profile.indexOf('profilePhotoUrl'),
          lessThan(profile.indexOf('photoURL')));
      expect(homeBloc.indexOf('profileThumbnailUrl'),
          lessThan(homeBloc.indexOf('photoURL')));
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
      expect(earnings, isNot(contains('CASH EARNINGS')));
      expect(earnings, contains('Available balance'));
      expect(earnings, contains('Payout history'));
      expect(earnings, contains('Transactions'));
      expect(earnings, contains('Waiting & No-show'));
      expect(earnings, contains('Adjustment'));
      expect(earnings, contains('Payout processing'));
      expect(earnings, contains('Payout failed'));
      expect(earnings, contains('Review required'));
      expect(earnings, contains('_requiresPayoutReview'));
      expect(earnings, contains('_NoEarningsState'));
      expect(earnings, isNot(contains('_FooterMeta')));
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

    test('profile tab hosts the rebuilt Rider professional profile', () {
      expect(profile, contains('_ProfilePhoto'));
      expect(profile, contains('Edit profile photo'));
      expect(profile, contains('Edit Profile'));
      expect(profile, contains('Deliveries Completed'));
      expect(profile, contains('Customer Rating'));
      expect(profile, contains('Acceptance Rate'));
      expect(profile, contains('On-Time Rate'));
      expect(profile, contains('Trust Points'));
      expect(profile, contains('Account'));
      expect(profile, contains('Work'));
      expect(profile, contains('Finance'));
      expect(profile, contains('Performance'));
      expect(profile, contains('Settings'));
      expect(profile, contains('Account Actions'));
      expect(profile, contains('Personal Details'));
      expect(profile, contains('Contact Information'));
      expect(profile, isNot(contains('Emergency Contact')));
      expect(profile, contains('Vehicles'));
      expect(profile, contains('Documents'));
      expect(profile, contains('Verification required'));
      expect(profile, contains('Verification in progress'));
      expect(profile, contains('Partially verified'));
      expect(profile, contains('Fully verified'));
      expect(profile, isNot(contains('Documents verified')));
      expect(profile, isNot(contains("title: 'Availability'")));
      expect(profile, contains('Earnings'));
      expect(profile, contains('Roth Wallet'));
      expect(profile, contains('Payout Account'));
      expect(profile, isNot(contains('Stripe Verification Status')));
      expect(profile, contains('Available Balance'));
      expect(profile, contains('Next Estimated Payout'));
      expect(profile, contains('Payout History'));
      expect(profile, contains('Transaction History'));
      expect(profile, contains('Rank & Trust'));
      expect(profile, contains('Achievements'));
      expect(profile, contains('Notifications'));
      expect(profile, contains('Accessibility'));
      expect(profile, contains('RiderAccessibilitySettingsView'));
      expect(accessibility, contains('Appearance'));
      expect(accessibility, contains('Text Size'));
      expect(accessibility, contains('High Contrast'));
      expect(accessibility, contains('Reduce Motion'));
      expect(accessibility, contains('Screen Reader Optimisations'));
      expect(accessibility, contains('SharedPreferences'));
      expect(profile, contains('Support'));
      expect(profile, contains('Application Centre'));
      expect(profile, isNot(contains('FAQ')));
      expect(support, isNot(contains('FAQ')));
      expect(File('lib/app/support/view/faq.dart').existsSync(), isFalse);
      expect(profileDetails, contains('Add vehicle'));
      expect(profileDetails, contains('Set active'));
      expect(profileDetails, contains("'vehicles': vehicles"));
      expect(profileDetails, contains("'vehicle': active"));
      expect(profileDetails, contains("_field(_phone, 'Phone',"));
      expect(profileDetails, contains('readOnly: true'));
      expect(profileDetails, isNot(contains("'phoneNumber': _phone.text")));
      expect(profileDetails, isNot(contains("'email': _email.text")));
      expect(profileDetails, contains('Manufacturer'));
      expect(profileDetails, contains('Registration'));
      expect(profileDetails, contains('Insurance'));
      expect(profileDetails, contains('MOT'));
      expect(profileDetails, isNot(contains('Emergency Contact')));
      expect(profile, contains('Privacy'));
      expect(profile, contains('Terms'));
      expect(profile, contains('Rider Agreement'));
      expect(
          profile.contains('Licences') && profile.contains('notices'), isFalse);
      expect(profile, contains('Sign Out'));
      expect(profile, contains('_RiderProfileScreen'));
      expect(profile, contains('_ProfileHero'));
      expect(profile, contains('_StatsRow'));
      expect(profile, isNot(contains('Operations & Account')));
      expect(profile, isNot(contains('Ready to work')));
      expect(profile, isNot(contains('Work preferences')));
      expect(profile, isNot(contains('App permissions')));
      expect(profile, isNot(contains('Earnings and payouts')));
      expect(profile, isNot(contains('Account milestones')));
      expect(profile, isNot(contains('RiderStatusBadge')));
      expect(profile, isNot(contains('RiderMetric')));
      expect(profile, isNot(contains('SwitchListTile')));
      expect(profile, isNot(contains('Jason Adesanya')));
      expect(profile, isNot(contains('WARDEN · 412 TRUST')));
      expect(profile, isNot(contains('Verified Rider')));
      expect(profile, isNot(contains('Preferred Delivery Types')));
      expect(profile, isNot(contains('Portal')));
      expect(profile, isNot(contains('portal')));
      expect(profile, isNot(contains('Sender UI')));
      expect(profile, isNot(contains('Admin UI')));
    });

    test('documents open the production Verification Centre', () {
      expect(verification, contains('Verification Centre'));
      expect(verification,
          contains('Complete your verification to unlock deliveries.'));
      expect(verification, contains('_ProgressRingPainter'));
      expect(verification, contains('verifications completed'));
      expect(verification, contains('Ready for Deliveries'));
      expect(verification, contains('Verification Required'));
      expect(verification, contains('Verification Under Review'));
      expect(verification, contains("Driver's Licence"));
      expect(verification, contains('Passport'));
      expect(verification, contains('Right to Work'));
      expect(verification,
          contains('Vehicle Registration, MOT, V5C and Road Tax'));
      expect(verification, contains('Insurance Company and Policy Expiry'));
      expect(verification, contains('Profile Photo'));
      expect(verification, contains('Verification Summary'));
      expect(verification, contains('Continue Verification'));
      expect(verification, contains('View Submitted Documents'));
      expect(verification, contains('Accepted formats'));
      expect(verification, contains('Maximum file size'));
      expect(verification, contains('Current submission'));
      expect(verification, contains('Reviewer comments'));
      expect(verification, contains('Resubmit'));
      expect(verification, contains('riderDocuments'));
      expect(verification, contains('riderApplications'));
      expect(verification, contains('RiderAccountStateResolver.resolve'));
      expect(verification, isNot(contains('unselected_radio.svg')));
      expect(verification, isNot(contains('Choose a mode of verification')));
      expect(verification, isNot(contains('Generic upload list')));
    });

    test('profile keeps protected fields read only and routes to details', () {
      expect(profile, contains('RiderRankSnapshot.from'));
      expect(profile, contains('rank'));
      expect(riderTruth, contains('trustPoints'));
      expect(profile, contains('VerificationView'));
      expect(profile, contains('RiderPersonalDetailsView'));
      expect(profile, isNot(contains('AccountDetails')));
      expect(profile, contains('RiderApplicationCentre'));
      expect(profile, contains('RiderAccessibilitySettingsView'));
      expect(profile, isNot(contains('updateRank')));
      expect(profile, isNot(contains('updateTrust')));
      expect(profile, isNot(contains('approvalStatus\':')));
    });

    test('profile keeps existing contextual routes and account actions', () {
      expect(profile, contains('RiderNotificationsView'));
      expect(profile, contains('SupportView'));
      expect(profile, contains("collection('riderProfiles')"));
      expect(profile, contains("collection('riders')"));
      expect(profile, contains("collection('riderEarnings')"));
      expect(profile, contains('RiderLegalView'));
      expect(profile, contains('showModalBottomSheet'));
      expect(profile, contains('SignOut()'));
      expect(profile, contains("httpsCallable('closeCircumAccount')"));
    });

    test('profile keeps Stripe payouts and Roth wallet separate', () {
      expect(profile, contains('Stripe Connect'));
      expect(profile, contains('Roth Wallet'));
      expect(profile, contains('Separate from cash earnings'));
      expect(profile, contains('separate from payouts'));
      expect(profile, isNot(contains('bank details')));
      expect(profile, isNot(contains('sort code')));
      expect(profile, isNot(contains('account number')));
    });

    test('profile avoids old operational and tax language', () {
      expect(profile, isNot(contains('Available earnings')));
      expect(profile, isNot(contains('pending earnings')));
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
