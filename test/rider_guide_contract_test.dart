import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonical Rider Guide', () {
    final guide =
        File('lib/app/onboarding/rider_guide_view.dart').readAsStringSync();
    final onboarding =
        File('lib/app/onboarding/view/onboarding.dart').readAsStringSync();
    final dashboard = File('lib/app/rider_shell/rider_dashboard_view.dart')
        .readAsStringSync();
    final profile =
        File('lib/app/rider_shell/rider_profile_view.dart').readAsStringSync();
    final pending =
        File('lib/app/authentication/view/application_submitted.dart')
            .readAsStringSync();
    final addDetails =
        File('lib/app/authentication/view/add_details.dart').readAsStringSync();
    final accountState = File('lib/app/rider_account/rider_account_state.dart')
        .readAsStringSync();
    final applicationCentre =
        File('lib/app/onboarding/rider_application_centre.dart')
            .readAsStringSync();

    test('new Riders see the guide before auth and viewed state persists', () {
      expect(onboarding, contains('RiderGuideView.hasViewedIntro'));
      expect(onboarding, contains('RiderGuideView('));
      expect(onboarding, contains('authenticated: false'));
      expect(
          onboarding, contains('_finishIntro(_RiderAuthStep.createAccount)'));
      expect(onboarding, contains('_finishIntro(_RiderAuthStep.signIn)'));
      expect(guide, contains('SharedPreferences.getInstance'));
      expect(guide, contains('circum_rider_intro_viewed'));
      expect(guide, contains('markIntroViewed'));
    });

    test('unauthenticated actions route to existing registration and sign-in',
        () {
      expect(guide, contains('Get started'));
      expect(guide, contains('Already have an account? Sign in'));
      expect(onboarding, contains('_RiderAuthStep.createAccount'));
      expect(onboarding, contains('_RiderAuthStep.signIn'));
      expect(onboarding, contains('SignUpWithEmail'));
      expect(onboarding, contains('SignInWithEmail'));
    });

    test('authenticated guide is session-safe and closeable', () {
      final authenticatedEntryPoints =
          '$dashboard\n$profile\n$pending\n$addDetails';
      expect(authenticatedEntryPoints, contains('authenticated: true'));
      expect(guide, contains('Open Application Centre'));
      expect(guide, contains('RiderApplicationCentre'));
      expect(guide, contains('Close guide'));
      expect(guide, isNot(contains('SignOut')));
      expect(guide, isNot(contains('SignUpWithEmail')));
    });

    test('Rider Guide remains reachable from core Rider surfaces', () {
      expect(dashboard, contains('RiderGuideEntryCard'));
      expect(dashboard, contains('RiderGuideView'));
      expect(profile, contains('Safety Centre'));
      expect(profile, contains('RiderGuideView'));
      expect(pending, contains('RiderGuideEntryCard'));
      expect(pending, contains('RiderGuideProgressCard'));
      expect(addDetails, contains('Rider Guide'));
      expect(addDetails, contains('RiderGuideView'));
    });

    test('Roth guidance is present and separate from cash', () {
      expect(guide, contains('ROTH WALLET'));
      expect(guide, contains('Roth is separate from Rider cash'));
      expect(guide, contains('Roth cannot be withdrawn to a bank account'));
      expect(guide, contains('Roth is not wages'));
      expect(
          guide, contains('Roth uses its own server-authorised wallet ledger'));
      expect(guide, isNot(contains('£ Roth')));
    });

    test('application progress remains backend-driven', () {
      expect(accountState, contains('phoneVerified'));
      expect(accountState, contains('documentsSubmitted'));
      expect(accountState, contains('vehicleDetails'));
      expect(accountState, contains('rothWalletSetup'));
      expect(accountState, contains('payoutSetup'));
      expect(accountState, contains('RiderApprovalProgress.fromBackend'));
      expect(guide, contains('Application progress'));
      expect(applicationCentre, contains('Application progress'));
      expect(guide, contains('Account created'));
      expect(guide, contains('Phone verified'));
      expect(guide, contains('Identity and documents'));
      expect(guide, contains('Vehicle details'));
      expect(guide, contains('Roth wallet setup'));
      expect(guide, contains('Payout setup'));
      expect(guide, contains('Admin review'));
    });

    test('approved Riders can reopen the same canonical guide', () {
      expect(guide, contains('progress?.approved == true'));
      expect(guide, contains('Learn how Circum Rider works.'));
      expect(profile, isNot(contains('Already have an account? Sign in')));
      expect(pending, isNot(contains('Get started')));
    });

    test('Application Centre contains the real Rider application sections', () {
      for (final label in [
        'Personal details',
        'Home address',
        'Contact details',
        'Identity verification',
        'Right-to-work information',
        'Vehicle details',
        'Vehicle documents',
        'Payout details',
        'Roth wallet setup',
        'Application messages',
        'Review status',
      ]) {
        expect(applicationCentre, contains(label));
      }
      expect(applicationCentre, contains('RiderApplicationSectionStatus'));
      expect(applicationCentre, contains('Not started'));
      expect(applicationCentre, contains('In progress'));
      expect(applicationCentre, contains('Submitted'));
      expect(applicationCentre, contains('Needs attention'));
      expect(applicationCentre, contains('Approved'));
    });

    test('Application Centre stores documents securely for Admin review', () {
      expect(applicationCentre, contains("storageRoot = 'rider-applications'"));
      expect(applicationCentre, contains('storagePath'));
      expect(applicationCentre, contains('riderDocuments'));
      expect(applicationCentre, contains('statusHistory'));
      expect(applicationCentre, contains('archivedVersions'));
      expect(applicationCentre, contains('under_review'));
      expect(applicationCentre, isNot(contains('publicDownloadUrl')));
    });

    test('Application Centre supports vehicles Roth and Admin messages', () {
      expect(applicationCentre, contains('maxVehicles = 2'));
      expect(applicationCentre, contains('V5C or MOT'));
      expect(applicationCentre, contains('insurance can be supplied later'));
      expect(applicationCentre, contains('ensureWalletForRider'));
      expect(applicationCentre, contains('RiderConversationView'));
      expect(applicationCentre, contains("admin_rider_"));
      expect(applicationCentre, contains('_application'));
    });

    test('Rider cannot approve their own application from the centre', () {
      expect(
          applicationCentre, isNot(contains("'approvalStatus': 'approved'")));
      expect(applicationCentre, isNot(contains("'approvedAt'")));
      expect(applicationCentre, contains('application_submitted'));
      expect(applicationCentre, contains('riderApplicationAudit'));
    });
  });
}
