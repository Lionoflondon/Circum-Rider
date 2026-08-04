import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

class RiderStripePayoutOnboarding {
  const RiderStripePayoutOnboarding({FirebaseFunctions? functions})
      : _functions = functions;

  final FirebaseFunctions? _functions;

  FirebaseFunctions get _callables =>
      _functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<void> openPayoutSetup({bool resume = false}) async {
    final callable = resume
        ? _callables.httpsCallable('refreshStripeOnboardingLink')
        : _callables.httpsCallable('createStripeOnboardingLink');
    final result = await callable.call();
    final data = Map<String, dynamic>.from(result.data as Map);
    final url = '${data['url'] ?? ''}'.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw StateError('Could not open payout setup. Please try again.');
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw StateError('Could not open payout setup. Please try again.');
    }
  }

  Future<Map<String, dynamic>> syncPayoutStatus() async {
    final result =
        await _callables.httpsCallable('syncStripeConnectStatus').call();
    return Map<String, dynamic>.from(result.data as Map);
  }
}

enum RiderPayoutReadiness {
  setupRequired,
  inProgress,
  additionalInformationRequired,
  payoutsEnabled,
  restricted,
  actionRequired,
}

RiderPayoutReadiness riderPayoutReadinessFrom(Map<String, dynamic> data) {
  final values = [
    data['connectReadiness'],
    data['stripeConnectStatus'],
    data['stripeStatus'],
    data['stripeOnboardingStatus'],
    data['payoutStatus'],
  ].map((value) => '${value ?? ''}'.trim().toLowerCase()).join(' ');
  if (data['stripePayoutsEnabled'] == true ||
      data['payoutsEnabled'] == true ||
      data['payoutSetupComplete'] == true ||
      data['onboardingComplete'] == true ||
      values.contains('payouts_enabled') ||
      values.contains('ready') ||
      values.contains('active')) {
    return RiderPayoutReadiness.payoutsEnabled;
  }
  if (values.contains('restricted') ||
      values.contains('disabled') ||
      values.contains('closed') ||
      values.contains('rejected')) {
    return RiderPayoutReadiness.restricted;
  }
  if (values.contains('action_required') ||
      values.contains('requirements_due')) {
    return RiderPayoutReadiness.actionRequired;
  }
  if (values.contains('pending') ||
      values.contains('under_review') ||
      values.contains('verification')) {
    return RiderPayoutReadiness.inProgress;
  }
  if (values.contains('onboarding') ||
      data['stripeOnboardingStarted'] == true ||
      data['stripeConnectAccountId'] != null ||
      data['stripeAccountId'] != null) {
    return RiderPayoutReadiness.additionalInformationRequired;
  }
  return RiderPayoutReadiness.setupRequired;
}

String riderPayoutReadinessLabel(RiderPayoutReadiness readiness) {
  return switch (readiness) {
    RiderPayoutReadiness.setupRequired => 'Complete payout setup',
    RiderPayoutReadiness.inProgress => 'Verification in progress',
    RiderPayoutReadiness.additionalInformationRequired => 'Action required',
    RiderPayoutReadiness.payoutsEnabled => 'Payouts enabled',
    RiderPayoutReadiness.restricted => 'Restricted',
    RiderPayoutReadiness.actionRequired => 'Action required',
  };
}

String riderPayoutReadinessBody(RiderPayoutReadiness readiness) {
  return switch (readiness) {
    RiderPayoutReadiness.setupRequired =>
      "You'll securely complete identity verification with Stripe.\n\nCircum never stores your bank details.\n\nOnce Stripe confirms your account, payouts become available automatically.",
    RiderPayoutReadiness.additionalInformationRequired ||
    RiderPayoutReadiness.actionRequired =>
      'Stripe needs additional information before your payouts can be enabled.',
    RiderPayoutReadiness.inProgress =>
      "Stripe is reviewing your information.\n\nWe'll automatically enable payouts as soon as verification is complete.",
    RiderPayoutReadiness.payoutsEnabled =>
      'Your Stripe account is ready.\n\nFuture earnings can now be paid out.',
    RiderPayoutReadiness.restricted =>
      'Your payout setup needs review before payouts can be enabled.',
  };
}

String riderPayoutReadinessActionLabel(RiderPayoutReadiness readiness) {
  return switch (readiness) {
    RiderPayoutReadiness.additionalInformationRequired ||
    RiderPayoutReadiness.actionRequired =>
      'Continue payout setup',
    _ => 'Complete payout setup',
  };
}

bool riderPayoutCanContinue(RiderPayoutReadiness readiness) {
  return readiness != RiderPayoutReadiness.payoutsEnabled &&
      readiness != RiderPayoutReadiness.restricted;
}
