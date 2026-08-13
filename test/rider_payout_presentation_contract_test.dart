import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final earnings = File(
    'lib/app/account/view/earnings.dart',
  ).readAsStringSync();
  final accountBloc = File(
    'lib/app/account/bloc/account_bloc.dart',
  ).readAsStringSync();

  test('Rider payout action uses the protected payout authority', () {
    expect(accountBloc, contains("httpsCallable('requestRiderWithdrawal')"));
    expect(accountBloc, contains("bankName: 'Verified bank account'"));
    expect(accountBloc, isNot(contains("bankName: 'Stripe Connect'")));
  });

  test('real Stripe lifecycle states block duplicate payout requests', () {
    final start = earnings.indexOf('bool _isActivePayout');
    final end = earnings.indexOf('bool _requiresPayoutReview', start);
    final activePolicy = earnings.substring(start, end);

    for (final status in [
      'requested',
      'pending',
      'reserved',
      'processing',
      'scheduled',
    ]) {
      expect(activePolicy, contains("'$status'"));
    }
    expect(activePolicy, isNot(contains("'approved'")));
  });

  test('legacy approval without Stripe evidence is truthful and non-blocking',
      () {
    expect(earnings, contains("status == 'approved'"));
    expect(earnings, contains("return 'Not sent'"));
    expect(earnings, contains("item['stripeTransferId'] == null"));
    expect(earnings, contains("item['stripePayoutId'] == null"));
    expect(earnings, contains("item['fundsReserved'] != true"));
    expect(earnings, contains('Your available cash was not reduced'));
  });

  test('Rider payout copy explains the human outcome', () {
    expect(earnings, contains("httpsCallable('getRiderPayoutQuote')"));
    expect(earnings, contains('Send to my bank'));
    expect(earnings, contains('Confirm payout'));
    expect(earnings, contains("label: 'Requested'"));
    expect(earnings, contains("label: 'Processing cost'"));
    expect(earnings, contains("label: 'Bank receives'"));
    expect(earnings, contains('processed securely by Stripe'));
    expect(earnings, contains('Bank receives'));
    expect(earnings, contains('processing cost'));
    expect(earnings, isNot(contains('Payout processing')));
    expect(earnings, isNot(contains('backend')));
    expect(earnings, isNot(contains('canonical')));
  });

  test('live wallet values outrank the one-time payout summary', () {
    expect(
      earnings.indexOf("storedEarnings['availableBalance']"),
      lessThan(earnings.indexOf("summary['storedAvailable']")),
    );
    expect(
      earnings.indexOf("storedEarnings['pendingWithdrawal']"),
      lessThan(earnings.indexOf("summary['pending']")),
    );
  });
}
