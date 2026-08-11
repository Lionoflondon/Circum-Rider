import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

Future<bool> initializeCircumAppCheck({
  FirebaseAppCheck? appCheck,
  bool debug = kDebugMode,
}) async {
  try {
    await (appCheck ?? FirebaseAppCheck.instance)
        .activate(
          androidProvider: debug
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider: debug
              ? AppleProvider.debug
              : AppleProvider.appAttestWithDeviceCheckFallback,
        )
        .timeout(const Duration(seconds: 8));
    return true;
  } on TimeoutException {
    return false;
  } catch (_) {
    return false;
  }
}
