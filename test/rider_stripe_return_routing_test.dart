import 'dart:io';

import 'package:circum_rider/app/stripe/rider_stripe_return.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rider Stripe return routing', () {
    test('restores the completed return path and query context', () {
      final intent = RiderStripeReturnIntent.fromUri(
        Uri.parse(
          'https://circum-rider-2797c.web.app/rider/stripe/return?riderId=rider-1',
        ),
      );

      expect(intent, isNotNull);
      expect(intent!.action, RiderStripeReturnAction.completed);
      expect(intent.canonicalPath, RiderStripeReturnIntent.returnPath);
      expect(intent.returnedRiderId, 'rider-1');
    });

    test('restores refresh with a trailing slash', () {
      final intent = RiderStripeReturnIntent.fromUri(
        Uri.parse(
          'https://circum-rider-2797c.web.app/rider/stripe/refresh/?riderId=rider-1',
        ),
      );

      expect(intent, isNotNull);
      expect(intent!.action, RiderStripeReturnAction.refresh);
      expect(intent.isRefresh, isTrue);
    });

    test('does not claim Website or unrelated paths', () {
      expect(
        RiderStripeReturnIntent.fromUri(
          Uri.parse('https://circumuk.com/rider/stripe/return'),
        ),
        isNull,
      );
      expect(
        RiderStripeReturnIntent.fromUri(
          Uri.parse('https://circum-rider-2797c.web.app/stripe/return'),
        ),
        isNull,
      );
    });

    test('waits for auth and never trusts the returned Rider ID', () {
      final app = File('lib/app.dart').readAsStringSync();
      final view = File(
        'lib/app/stripe/rider_stripe_return_view.dart',
      ).readAsStringSync();
      final web = File('lib/main_rider_web.dart').readAsStringSync();

      expect(web, contains('RiderStripeReturnIntent.fromUri(Uri.base)'));
      expect(app, contains('state.currentState == AppState.authenticated'));
      expect(app, contains('RiderStripeReturnView'));
      expect(view, contains("httpsCallable('syncStripeConnectStatus')"));
      expect(view, contains("httpsCallable('refreshStripeOnboardingLink')"));
      expect(view, contains("call(const <String, dynamic>{})"));
      expect(view, isNot(contains("'riderId':")));
    });

    test('authenticated launcher starts Stripe in the Rider Web context', () {
      final launcher = File(
        'lib/app/stripe/rider_stripe_onboarding_launcher.dart',
      ).readAsStringSync();
      final earnings =
          File('lib/app/account/view/earnings.dart').readAsStringSync();
      final applicationCentre = File(
        'lib/app/onboarding/rider_application_centre.dart',
      ).readAsStringSync();

      expect(launcher, contains('FirebaseAuth.instance.currentUser'));
      expect(
        launcher,
        contains("httpsCallable('createStripeOnboardingLink')"),
      );
      expect(launcher, contains('const <String, dynamic>{}'));
      expect(launcher, isNot(contains("'riderId':")));
      expect(launcher, contains('static Future<void>? _opening'));
      expect(launcher, contains('if (active != null) return active'));
      expect(launcher, contains("url.scheme != 'https'"));
      expect(launcher, contains("kIsWeb ? '_self' : null"));
      expect(earnings, contains('RiderStripeOnboardingLauncher.open()'));
      expect(
          applicationCentre, contains('RiderStripeOnboardingLauncher.open()'));
    });
  });
}
