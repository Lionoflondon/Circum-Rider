import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class RiderStripeOnboardingLauncher {
  const RiderStripeOnboardingLauncher._();

  static Future<void>? _opening;

  static Future<void> open() {
    final active = _opening;
    if (active != null) return active;
    final opening = _open();
    _opening = opening;
    return opening.whenComplete(() {
      if (identical(_opening, opening)) _opening = null;
    });
  }

  static Future<void> _open() async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw StateError('Sign in to Circum Rider before setting up payouts.');
    }

    final response = await FirebaseFunctions.instanceFor(
      region: 'us-central1',
    ).httpsCallable('createStripeOnboardingLink').call(
      const <String, dynamic>{},
    );
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : const <String, dynamic>{};
    final url = Uri.tryParse('${data['url'] ?? ''}');
    if (url == null || url.scheme != 'https' || url.host.trim().isEmpty) {
      throw StateError('Stripe did not return a secure onboarding link.');
    }

    final opened = await launchUrl(
      url,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: kIsWeb ? '_self' : null,
    );
    if (!opened) {
      throw StateError('Stripe onboarding could not be opened.');
    }
  }
}
