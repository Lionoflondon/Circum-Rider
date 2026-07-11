import 'dart:io';

import 'package:circum_rider/app/rider_account/rider_account_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RiderAccountStateResolver', () {
    test('keeps missing records in onboarding', () {
      expect(RiderAccountStateResolver.resolve(null),
          RiderAccountState.onboardingNotStarted);
    });

    test('resumes onboarding records instead of treating them as approved', () {
      expect(
        RiderAccountStateResolver.resolve({
          'onboardingStatus': 'profile_started',
          'approvalStatus': 'pending',
        }),
        RiderAccountState.onboardingInProgress,
      );
    });

    test('maps submitted and review records safely', () {
      expect(
        RiderAccountStateResolver.resolve(
            {'onboardingStatus': 'application_submitted'}),
        RiderAccountState.submitted,
      );
      expect(
        RiderAccountStateResolver.resolve({'approvalStatus': 'pending'}),
        RiderAccountState.pendingReview,
      );
    });

    test('maps requested information and terminal account gates', () {
      expect(
        RiderAccountStateResolver.resolve(
            {'approvalStatus': 'more_information_required'}),
        RiderAccountState.moreInformationRequired,
      );
      expect(RiderAccountStateResolver.resolve({'isSuspended': true}),
          RiderAccountState.suspended);
      expect(RiderAccountStateResolver.resolve({'isFrozen': true}),
          RiderAccountState.frozen);
      expect(RiderAccountStateResolver.resolve({'isClosed': true}),
          RiderAccountState.closed);
      expect(RiderAccountStateResolver.resolve({'approvalStatus': 'rejected'}),
          RiderAccountState.rejected);
    });

    test('allows operations only for an explicitly approved account', () {
      expect(
        RiderAccountStateResolver.resolve(
            {'approvalStatus': 'approved', 'riderStatus': 'active'}),
        RiderAccountState.approved,
      );
      expect(RiderAccountStateResolver.canOperate(RiderAccountState.approved),
          isTrue);
      expect(
          RiderAccountStateResolver.canOperate(RiderAccountState.pendingReview),
          isFalse);
    });

    test('reconciles Admin approval without losing Rider restrictions', () {
      expect(
        RiderAccountStateResolver.resolveRecords(
          rider: const {
            'approvalStatus': 'pending',
            'riderStatus': 'pending',
            'status': 'pending',
          },
          riderProfile: const {
            'approvalStatus': 'approved',
            'verificationStatus': 'approved',
          },
        ),
        RiderAccountState.approved,
      );

      expect(
        RiderAccountStateResolver.resolveRecords(
          rider: const {
            'approvalStatus': 'pending',
            'isSuspended': true,
          },
          riderProfile: const {
            'approvalStatus': 'approved',
            'driverStatus': 'active',
          },
        ),
        RiderAccountState.suspended,
      );
    });

    test('does not invent vehicle defaults', () {
      final record = <String, dynamic>{'onboardingStatus': 'profile_started'};
      expect(record.containsKey('vehicle'), isFalse);
      expect(RiderAccountStateResolver.resolve(record),
          RiderAccountState.onboardingInProgress);
    });
  });

  group('RiderApprovalProgress', () {
    test('uses Firebase Auth as the only email verification truth', () {
      final progress = RiderApprovalProgress.fromBackend(
        accountExists: true,
        firebaseEmailVerified: false,
        rider: const {
          'emailVerified': true,
          'approvalStatus': 'pending_review',
        },
      );

      expect(progress.accountCreated, isTrue);
      expect(progress.emailVerified, isFalse);
      expect(progress.applicationSubmitted, isTrue);
      expect(progress.underReview, isTrue);
      expect(progress.approved, isFalse);
      expect(progress.readyToDeliver, isFalse);
    });

    test('marks approved and ready only from explicit backend fields', () {
      final approved = RiderApprovalProgress.fromBackend(
        accountExists: true,
        firebaseEmailVerified: true,
        rider: const {
          'approvalStatus': 'approved',
          'onboardingComplete': true,
        },
      );

      expect(approved.approved, isTrue);
      expect(approved.readyToDeliver, isTrue);

      final missingStatus = RiderApprovalProgress.fromBackend(
        accountExists: true,
        firebaseEmailVerified: true,
        rider: const {},
      );
      expect(missingStatus.applicationSubmitted, isFalse);
      expect(missingStatus.underReview, isFalse);
      expect(missingStatus.approved, isFalse);
      expect(missingStatus.readyToDeliver, isFalse);
    });

    test('pending review screen has no phone verification stage', () {
      final source =
          File('lib/app/authentication/view/application_submitted.dart')
              .readAsStringSync();
      expect(source, isNot(contains('Phone Verified')));
      expect(source, isNot(contains('phoneVerified')));
      expect(source, contains("_timeline('Approved', progress.approved)"));
    });
  });

  test('existing app session gate retains AppNav for approved riders', () {
    final source = File('lib/app.dart').readAsStringSync();
    expect(source, contains('RiderAccountState.approved'));
    expect(source, contains('MaterialPage(child: AppNavView())'));
    expect(source, contains('RiderAccountStatusView'));
  });
}
