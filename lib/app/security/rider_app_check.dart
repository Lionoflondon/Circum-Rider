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
    return const RiderAppCheckStartup.ready();
  }
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
      webProvider: kIsWeb ? ReCaptchaEnterpriseProvider(siteKey) : null,
    );
    return const RiderAppCheckStartup.ready();
  } catch (_) {
    return const RiderAppCheckStartup.ready();
  }
}
