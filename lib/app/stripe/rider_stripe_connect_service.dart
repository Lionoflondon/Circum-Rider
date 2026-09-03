import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

typedef RiderStripeCall = Future<Map<String, dynamic>> Function(String name);
typedef RiderStripeUrlLauncher = Future<bool> Function(Uri url);

class RiderStripeConnectFailure implements Exception {
  const RiderStripeConnectFailure(this.message);

  final String message;
}

class RiderStripeConnectService {
  RiderStripeConnectService({
    RiderStripeCall? call,
    RiderStripeUrlLauncher? launch,
    this.timeout = const Duration(seconds: 25),
  })  : _call = call ?? _firebaseCall,
        _launch = launch ?? _launchExternal;

  final RiderStripeCall _call;
  final RiderStripeUrlLauncher _launch;
  final Duration timeout;

  Future<Map<String, dynamic>> refresh() =>
      _boundedCall('syncStripeConnectStatus');

  Future<void> openAccount() async {
    try {
      final status = await refresh();
      final detailsSubmitted = status['stripeDetailsSubmitted'] == true ||
          status['onboardingComplete'] == true;
      final result = detailsSubmitted
          ? await _boundedCall('createStripeAccountManagementLink')
          : await _openOnboarding();
      final url = Uri.tryParse('${result['url'] ?? ''}');
      if (url == null || url.scheme != 'https' || url.host.isEmpty) {
        throw const RiderStripeConnectFailure(
          'Payout account setup is temporarily unavailable. Try again.',
        );
      }
      final opened = await _launch(url).timeout(timeout);
      if (!opened) {
        throw const RiderStripeConnectFailure(
          'Payout account setup could not be opened. Try again.',
        );
      }
    } on RiderStripeConnectFailure {
      rethrow;
    } on TimeoutException {
      throw const RiderStripeConnectFailure(
        'Payout account setup took too long. Check your connection and retry.',
      );
    } catch (_) {
      throw const RiderStripeConnectFailure(
        'Payout account setup could not be completed. Try again.',
      );
    }
  }

  Future<Map<String, dynamic>> _openOnboarding() async {
    await _boundedCall('createStripeConnectAccountForRider');
    return _boundedCall('createStripeOnboardingLink');
  }

  Future<Map<String, dynamic>> _boundedCall(String name) =>
      _call(name).timeout(timeout);

  static Future<Map<String, dynamic>> _firebaseCall(String name) async {
    final response = await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable(name)
        .call(const <String, dynamic>{});
    return response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : const <String, dynamic>{};
  }

  static Future<bool> _launchExternal(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);
}
