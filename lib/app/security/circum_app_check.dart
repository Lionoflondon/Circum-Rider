import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

const circumWebRecaptchaEnterpriseSiteKey = String.fromEnvironment(
  'CIRCUM_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY',
);

Future<bool> initializeCircumAppCheck({
  FirebaseAppCheck? appCheck,
  bool isWeb = kIsWeb,
  bool debug = kDebugMode,
}) async {
  final siteKey = circumWebRecaptchaEnterpriseSiteKey.trim();
  if (isWeb && siteKey.isEmpty) return false;
  try {
    await (appCheck ?? FirebaseAppCheck.instance)
        .activate(
          androidProvider:
              debug ? AndroidProvider.debug : AndroidProvider.playIntegrity,
          appleProvider: debug
              ? AppleProvider.debug
              : AppleProvider.appAttestWithDeviceCheckFallback,
          webProvider: isWeb ? ReCaptchaEnterpriseProvider(siteKey) : null,
        )
        .timeout(const Duration(seconds: 8));
    return true;
  } on TimeoutException {
    return false;
  } catch (_) {
    return false;
  }
}
