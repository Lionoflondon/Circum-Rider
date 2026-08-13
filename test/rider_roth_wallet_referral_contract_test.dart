import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Roth Wallet owns the Rider referral surface and backend authorities',
      () {
    final profile =
        File('lib/app/rider_shell/rider_profile_view.dart').readAsStringSync();
    final referral = File('lib/app/rider_shell/rider_roth_referral_view.dart')
        .readAsStringSync();
    final onboarding = File('lib/app/onboarding/rider_roth_onboarding.dart')
        .readAsStringSync();

    expect(profile, contains("title: 'Roth Wallet'"));
    expect(profile, contains('const RiderRothReferralView()'));
    expect(referral, contains("httpsCallable('getReferralDashboard')"));
    expect(onboarding, contains("httpsCallable('ensureRiderRothWallet')"));
    expect(onboarding, isNot(contains("collection('riderRothWallets')")));
  });
}
