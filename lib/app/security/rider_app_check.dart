import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class RiderAppCheckStartup {
  const RiderAppCheckStartup._({
    required this.blockStartup,
    required this.message,
  });

  const RiderAppCheckStartup.ready() : this._(blockStartup: false, message: '');

  const RiderAppCheckStartup.blocked(String message)
      : this._(blockStartup: true, message: message);

  final bool blockStartup;
  final String message;
}

Future<RiderAppCheckStartup> initializeRiderAppCheck() async {
  const siteKey =
      String.fromEnvironment('RIDER_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY');
  if (kIsWeb && siteKey.trim().isEmpty) {
    return const RiderAppCheckStartup.blocked(
      'Rider security verification is not configured for this version.',
    );
  }
  try {
    final activation = FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
      webProvider: kIsWeb ? ReCaptchaEnterpriseProvider(siteKey) : null,
    );
    if (kIsWeb) {
      await activation.timeout(const Duration(seconds: 5));
    } else {
      await activation;
    }
    return const RiderAppCheckStartup.ready();
  } catch (_) {
    if (kIsWeb) {
      return const RiderAppCheckStartup.blocked(
        'Rider security verification could not start. Please try again.',
      );
    }
    return const RiderAppCheckStartup.ready();
  }
}
