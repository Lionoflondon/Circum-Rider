import 'dart:io';

import 'package:circum_rider/app/onboarding/rider_roth_onboarding.dart';
import 'package:circum_rider/app/rider_account/rider_account_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rider Roth onboarding', () {
    final authBloc =
        File('lib/app/authentication/bloc/auth_bloc.dart').readAsStringSync();
    final earnings =
        File('lib/app/account/view/earnings.dart').readAsStringSync();
    final service = File('lib/app/onboarding/rider_roth_onboarding.dart')
        .readAsStringSync();

    test('wallet onboarding service is present and idempotent by rider UID',
        () {
      expect(RiderRothOnboarding.walletCollection, 'riderRothWallets');
      expect(RiderRothOnboarding.ledgerCollection, 'riderRothLedger');
      expect(service, contains("httpsCallable('ensureRiderRothWallet')"));
      expect(service, contains("'riderId': riderId"));
      expect(service, isNot(contains('runTransaction')));
      expect(service, isNot(contains("collection('riderRothWallets')")));
      expect(service, isNot(contains('FieldValue.increment')));
    });

    test('auth onboarding invokes Roth wallet connection without approving',
        () {
      expect(authBloc, contains('RiderRothOnboarding'));
      expect(authBloc, contains('ensureWalletForRider'));
      expect(authBloc, isNot(contains("'approvalStatus': 'pending'")));
      expect(authBloc,
          isNot(contains("'verificationStatus': 'verification_pending'")));
      expect(authBloc, isNot(contains("'approvalStatus': 'approved'")));
      expect(authBloc, isNot(contains("'onboardingStatus': 'approved'")));
    });

    test('Roth onboarding required keeps Rider in onboarding', () {
      expect(
        RiderAccountStateResolver.resolve({
          'approvalStatus': 'approved',
          'riderStatus': 'active',
          'rothOnboardingStatus': 'required',
        }),
        RiderAccountState.onboardingInProgress,
      );
    });

    test('Roth remains separate from cash and payouts', () {
      expect(
          RiderRothOnboarding.isCashLedgerCollection('riderEarnings'), isTrue);
      expect(
          RiderRothOnboarding.isCashLedgerCollection('payoutRequests'), isTrue);
      expect(RiderRothOnboarding.isCashLedgerCollection('riderRothLedger'),
          isFalse);
      expect(earnings, contains('Roth remains separate'));
      expect(earnings, isNot(contains('Roth withdrawal')));
      expect(earnings, isNot(contains('Stripe Roth')));
    });
  });
}
