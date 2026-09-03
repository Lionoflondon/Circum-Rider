import 'dart:async';

import 'package:circum_rider/app/stripe/rider_stripe_connect_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('incomplete account resumes hosted onboarding without a client UID',
      () async {
    final calls = <String>[];
    Uri? opened;
    final service = RiderStripeConnectService(
      call: (name) async {
        calls.add(name);
        return switch (name) {
          'syncStripeConnectStatus' => {'stripeDetailsSubmitted': false},
          'createStripeConnectAccountForRider' => {'alreadyExists': true},
          'createStripeOnboardingLink' => {
              'url': 'https://connect.stripe.test/setup'
            },
          _ => throw StateError(name),
        };
      },
      launch: (url) async {
        opened = url;
        return true;
      },
    );

    await service.openAccount();

    expect(calls, [
      'syncStripeConnectStatus',
      'createStripeConnectAccountForRider',
      'createStripeOnboardingLink',
    ]);
    expect(opened, Uri.parse('https://connect.stripe.test/setup'));
  });

  test('completed account opens Stripe account management', () async {
    final calls = <String>[];
    final service = RiderStripeConnectService(
      call: (name) async {
        calls.add(name);
        return name == 'syncStripeConnectStatus'
            ? {'stripeDetailsSubmitted': true, 'stripePayoutsEnabled': true}
            : {'url': 'https://connect.stripe.test/dashboard'};
      },
      launch: (_) async => true,
    );

    await service.openAccount();

    expect(calls, [
      'syncStripeConnectStatus',
      'createStripeAccountManagementLink',
    ]);
  });

  test('timeout is terminal and exposes only safe Rider copy', () async {
    final service = RiderStripeConnectService(
      timeout: const Duration(milliseconds: 10),
      call: (_) => Completer<Map<String, dynamic>>().future,
      launch: (_) async => true,
    );

    await expectLater(
      service.openAccount(),
      throwsA(
        isA<RiderStripeConnectFailure>().having(
          (error) => error.message,
          'message',
          contains('took too long'),
        ),
      ),
    );
  });

  test('non-HTTPS provider links fail closed', () async {
    final service = RiderStripeConnectService(
      call: (name) async => name == 'syncStripeConnectStatus'
          ? {'stripeDetailsSubmitted': true}
          : {'url': 'javascript:alert(1)'},
      launch: (_) async => true,
    );

    await expectLater(
      service.openAccount(),
      throwsA(isA<RiderStripeConnectFailure>()),
    );
  });
}
