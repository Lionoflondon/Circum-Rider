import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finance operations are bounded and resolve current auth identity', () {
    final bloc =
        File('lib/app/account/bloc/account_bloc.dart').readAsStringSync();
    final earnings =
        File('lib/app/account/view/earnings.dart').readAsStringSync();

    expect(bloc, contains('.timeout(operationTimeout)'));
    expect(bloc, contains('auth.currentUser?.uid'));
    expect(bloc, isNot(contains('User? user = auth.currentUser')));
    expect(earnings, contains('.timeout(const Duration(seconds: 25))'));
    expect(earnings, contains('BlocConsumer<AccountBloc, AccountState>'));
  });

  test('profile and Application Centre open canonical payout account', () {
    final profile =
        File('lib/app/rider_shell/rider_profile_view.dart').readAsStringSync();
    final application = File('lib/app/onboarding/rider_application_centre.dart')
        .readAsStringSync();

    expect(profile, contains('const RiderPayoutAccountView()'));
    expect(application, contains('const RiderPayoutAccountView()'));
    expect(profile, contains('No payout currently scheduled'));
  });

  test('native map controller callbacks cannot wait forever', () {
    final maps = File('lib/app/home/view/maps_view.dart').readAsStringSync();

    expect(maps, contains('_controller.future.timeout(_mapControllerTimeout)'));
    expect(maps, contains('if (!_controller.isCompleted)'));
    expect(maps, contains('if (points.isEmpty) return;'));
  });

  test('transaction history includes the authoritative delivery ledger', () {
    final earnings =
        File('lib/app/account/view/earnings.dart').readAsStringSync();

    expect(earnings, contains("_mapList(summary['production'])"));
    expect(earnings, contains('authoritativeTransactions.values.toList()'));
    expect(earnings, isNot(contains("'View all'")));
  });
}
