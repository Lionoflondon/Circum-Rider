import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

const riderRecaptchaEnterpriseSiteKey =
    String.fromEnvironment('RIDER_RECAPTCHA_ENTERPRISE_SITE_KEY');

class RiderAppCheckStartup {
  const RiderAppCheckStartup._({
    required this.enabled,
    required this.blockStartup,
    required this.message,
  });

  const RiderAppCheckStartup.enabled()
      : this._(
          enabled: true,
          blockStartup: false,
          message: '',
        );

  const RiderAppCheckStartup.blocked(String message)
      : this._(
          enabled: false,
          blockStartup: true,
          message: message,
        );

  final bool enabled;
  final bool blockStartup;
  final String message;
}

AndroidProvider riderAndroidAppCheckProvider({required bool debug}) {
  return debug ? AndroidProvider.debug : AndroidProvider.playIntegrity;
}

AppleProvider riderAppleAppCheckProvider({required bool debug}) {
  return debug
      ? AppleProvider.debug
      : AppleProvider.appAttestWithDeviceCheckFallback;
}

ReCaptchaEnterpriseProvider? riderWebAppCheckProvider({
  required bool isWeb,
  required String siteKey,
}) {
  if (!isWeb) return null;
  final trimmed = siteKey.trim();
  if (trimmed.isEmpty) return null;
  return ReCaptchaEnterpriseProvider(trimmed);
}

Future<RiderAppCheckStartup> initializeRiderAppCheck({
  FirebaseAppCheck? appCheck,
  bool isWeb = kIsWeb,
  bool debug = kDebugMode,
  String webSiteKey = riderRecaptchaEnterpriseSiteKey,
}) async {
  final webProvider = riderWebAppCheckProvider(
    isWeb: isWeb,
    siteKey: webSiteKey,
  );

  if (isWeb && webProvider == null) {
    return const RiderAppCheckStartup.blocked(
      'Rider security verification is not configured for this web build.',
    );
  }

  try {
    await (appCheck ?? FirebaseAppCheck.instance).activate(
      androidProvider: riderAndroidAppCheckProvider(debug: debug),
      appleProvider: riderAppleAppCheckProvider(debug: debug),
      webProvider: webProvider,
    );
    return const RiderAppCheckStartup.enabled();
  } catch (_) {
    return const RiderAppCheckStartup.blocked(
      'Rider security verification is temporarily unavailable.',
    );
  }
}
