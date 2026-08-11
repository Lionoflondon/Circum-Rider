import 'package:firebase_app_check/firebase_app_check.dart';

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
  const siteKey = String.fromEnvironment(
    'RIDER_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY',
  );
  if (siteKey.trim().isEmpty) {
    return const RiderAppCheckStartup.blocked(
      'Rider security verification is not configured for this version.',
    );
  }
  try {
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaEnterpriseProvider(siteKey),
    );
    return const RiderAppCheckStartup.ready();
  } catch (_) {
    return const RiderAppCheckStartup.blocked(
      'Rider security verification could not start. Please try again.',
    );
  }
}
