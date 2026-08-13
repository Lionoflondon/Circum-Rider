import 'dart:io';

import 'package:circum_rider/app/rider_shell/rider_roth_referral_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Roth Wallet owns the Rider referral surface and backend authorities',
    () {
      final profile = File(
        'lib/app/rider_shell/rider_profile_view.dart',
      ).readAsStringSync();
      final referral = File(
        'lib/app/rider_shell/rider_roth_referral_view.dart',
      ).readAsStringSync();
      final onboarding = File(
        'lib/app/onboarding/rider_roth_onboarding.dart',
      ).readAsStringSync();
      final earnings = File(
        'lib/app/account/view/earnings.dart',
      ).readAsStringSync();

      expect(profile, contains("title: 'Roth Wallet'"));
      expect(profile, contains('const RiderRothReferralView()'));
      expect(earnings, contains('const RiderRothWalletSummaryCard()'));
      expect(referral, contains("httpsCallable('getRiderRothWallet')"));
      expect(referral, contains("httpsCallable('getRiderRothTransactions')"));
      expect(referral, contains("httpsCallable('ensureReferralCode')"));
      expect(referral, contains("httpsCallable('getReferralDashboard')"));
      expect(referral, contains('How referral rewards move'));
      expect(referral, contains('Your available balance'));
      expect(referral, isNot(contains('The backend')));
      expect(referral, isNot(contains('canonical Roth')));
      expect(onboarding, contains("httpsCallable('ensureRiderRothWallet')"));
      expect(onboarding, isNot(contains("collection('riderRothWallets')")));
    },
  );

  test(
    'pending referral value is not presented as a completed Roth credit',
    () {
      final pending = RiderReferralRecord.fromMap({
        'referralId': 'ref-1',
        'rewardStatus': 'SIGNED_UP',
        'rewardAmount': 5,
      });
      final credited = RiderReferralRecord.fromMap({
        'referralId': 'ref-2',
        'rewardStatus': 'ROTH_AWARDED',
        'rewardAmount': 5,
      });
      final unknown = RiderReferralRecord.fromMap({
        'referralId': 'ref-3',
        'rewardStatus': 'FUTURE_STATE',
        'rewardAmount': 5,
      });

      expect(pending.credited, isFalse);
      expect(pending.amountLabel, '5 Roth pending');
      expect(credited.credited, isTrue);
      expect(credited.amountLabel, '+5 Roth');
      expect(unknown.credited, isFalse);
      expect(unknown.amountLabel, 'Awaiting verification');
    },
  );

  test('canonical ledger transactions preserve credit and debit direction', () {
    final credit = RiderRothTransaction.fromMap({
      'transactionId': 'credit-1',
      'type': 'referral_reward',
      'direction': 'credit',
      'amount': 5,
      'status': 'completed',
    });
    final debit = RiderRothTransaction.fromMap({
      'transactionId': 'debit-1',
      'type': 'roth_spend',
      'direction': 'debit',
      'amount': 2.5,
      'status': 'completed',
    });

    expect(credit.title, 'Referral reward');
    expect(credit.amountLabel, '+5 Roth');
    expect(debit.title, 'Roth used');
    expect(debit.amountLabel, '-2.50 Roth');
  });

  testWidgets('Rider Roth Wallet renders balance and ledger activity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RiderRothReferralView(dataSource: _FakeRothDataSource()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Roth Wallet'), findsOneWidget);
    expect(find.text('12 Roth'), findsOneWidget);
    expect(find.text('Recent Roth activity'), findsOneWidget);
    expect(find.text('Referral reward'), findsOneWidget);
    expect(find.text('+5 Roth'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRothDataSource implements RiderRothWalletDataSource {
  @override
  Future<RiderRothWallet> loadWallet() async =>
      const RiderRothWallet(balance: 12, status: 'active', currency: 'ROTH');

  @override
  Future<RiderRothTransactionPage> loadTransactions({String? pageToken}) async {
    return RiderRothTransactionPage.fromMap({
      'balance': 12,
      'status': 'active',
      'currency': 'ROTH',
      'transactions': [
        {
          'transactionId': 'referral-credit-1',
          'type': 'referral_reward',
          'direction': 'credit',
          'amount': 5,
          'balanceAfter': 12,
          'status': 'completed',
          'description': 'Verified referral reward',
        },
      ],
    });
  }

  @override
  Future<RiderReferralDashboard> loadReferrals() async {
    return RiderReferralDashboard.fromMap({
      'referralCode': 'RIDER123',
      'referralLink': 'https://circumuk.com/join/RIDER123',
      'referrals': const [],
    });
  }
}
