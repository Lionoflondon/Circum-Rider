import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider application centre wires Stripe Connect hosted onboarding', () {
    final source = File(
      'lib/app/onboarding/rider_application_centre.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("httpsCallable('createStripeConnectAccountForRider')"),
    );
    expect(source, contains("httpsCallable('createStripeOnboardingLink')"));
    expect(source, contains("httpsCallable('syncStripeConnectStatus')"));
    expect(source, contains('LaunchMode.externalApplication'));
    expect(source, contains('Stripe did not return a valid onboarding link'));
    expect(source, contains('WidgetsBinding.instance.addObserver(this)'));
    expect(source, contains('didChangeAppLifecycleState'));
    expect(
      source,
      isNot(contains("httpsCallable('createRiderTransferOrPayout')")),
    );
  });

  test('Rider earnings setup-required action opens hosted onboarding', () {
    final source = File(
      'lib/app/account/view/earnings.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("httpsCallable('createStripeConnectAccountForRider')"),
    );
    expect(source, contains("httpsCallable('createStripeOnboardingLink')"));
    expect(source, contains("httpsCallable('syncStripeConnectStatus')"));
    expect(source, contains('LaunchMode.externalApplication'));
    expect(source, contains("readiness == 'setup_required'"));
    expect(source, contains("readiness == 'restricted'"));
    expect(source, contains("readiness == 'disabled'"));
    expect(source, contains('_payoutOnboardingOpened'));
    expect(
      source,
      isNot(contains("httpsCallable('createRiderTransferOrPayout')")),
    );
  });

  test(
    'Rider app does not collect bank details for Stripe Connect onboarding',
    () {
      final onboarding = File(
        'lib/app/onboarding/rider_application_centre.dart',
      ).readAsStringSync();
      final earnings = File(
        'lib/app/account/view/earnings.dart',
      ).readAsStringSync();
      final combined = '$onboarding\n$earnings'.toLowerCase();

      expect(combined, isNot(contains('account number')));
      expect(combined, isNot(contains('sort code')));
      expect(combined, isNot(contains('iban')));
      expect(combined, isNot(contains('bank detail')));
    },
  );
}
