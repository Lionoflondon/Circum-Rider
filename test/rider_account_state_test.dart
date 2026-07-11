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

    test('does not invent vehicle defaults', () {
      final record = <String, dynamic>{'onboardingStatus': 'profile_started'};
      expect(record.containsKey('vehicle'), isFalse);
      expect(RiderAccountStateResolver.resolve(record),
          RiderAccountState.onboardingInProgress);
    });
  });

  test('existing app session gate retains AppNav for approved riders', () {
    final source = File('lib/app.dart').readAsStringSync();
    expect(source, contains('RiderAccountState.approved'));
    expect(source, contains('MaterialPage(child: AppNavView())'));
    expect(source, contains('RiderAccountStatusView'));
  });
}
