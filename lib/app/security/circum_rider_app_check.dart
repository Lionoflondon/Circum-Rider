import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const _webSiteKey = String.fromEnvironment(
  'CIRCUM_RIDER_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY',
);

Future<bool> initializeRiderAppCheck({
  FirebaseAppCheck? appCheck,
  bool debug = kDebugMode,
}) async {
  if (kIsWeb && _webSiteKey.trim().isEmpty) return false;
  try {
    await (appCheck ?? FirebaseAppCheck.instance).activate(
      androidProvider:
          debug ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: debug
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
      webProvider:
          kIsWeb ? ReCaptchaEnterpriseProvider(_webSiteKey.trim()) : null,
    );
    return true;
  } catch (_) {
    return false;
  }
}

class RiderSecurityBlocked extends StatelessWidget {
  const RiderSecurityBlocked({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Security verification unavailable.')),
        ),
      );
}
