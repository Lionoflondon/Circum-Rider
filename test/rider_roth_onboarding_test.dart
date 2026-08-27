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

    test('wallet onboarding uses the authoritative idempotent callable', () {
      expect(RiderRothOnboarding.walletCollection, 'riderRothWallets');
      expect(RiderRothOnboarding.ledgerCollection, 'riderRothLedger');
      expect(service, contains("httpsCallable('ensureRiderRothWallet')"));
      expect(service, contains("'riderId': riderId"));
      expect(service, contains("data['walletCreated']"));
      expect(service, isNot(contains('FirebaseFirestore')));
      expect(service, isNot(contains('runTransaction')));
      expect(service, isNot(contains("collection('riderRothWallets')")));
    });

    test('auth onboarding invokes server-authoritative wallet connection', () {
      expect(authBloc, contains("httpsCallable('ensureRiderRothWallet')"));
      expect(authBloc, contains('await ensureRiderRothWallet(user)'));
      expect(authBloc, isNot(contains('RiderRothOnboarding')));
      expect(authBloc, isNot(contains('ensureWalletForRider')));
      expect(authBloc, isNot(contains("collection('riderRothWallets')")));
      expect(authBloc, contains("'onboardingStatus': 'profile_complete'"));
      expect(authBloc, contains("httpsCallable('advanceRiderOnboarding')"));
      for (final field in [
        'role',
        'roles',
        'approvalStatus',
        'verificationStatus',
        'driverStatus',
        'riderRank',
        'rating',
      ]) {
        expect(
          authBloc,
          isNot(contains("'$field':")),
          reason: '$field must remain server-authoritative',
        );
      }
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
