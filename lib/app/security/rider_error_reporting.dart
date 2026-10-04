import 'dart:async';
import 'dart:ui';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

bool _installed = false;

/// Never attach account IDs, payloads, payment details or exception messages.
Future<void> initializeRiderErrorReporting() async {
  if (kIsWeb || _installed) return;
  final reporter = FirebaseCrashlytics.instance;
  await reporter
      .setCrashlyticsCollectionEnabled(kReleaseMode)
      .timeout(const Duration(seconds: 3));
  if (!kReleaseMode) return;
  _installed = true;
  final previousFlutter = FlutterError.onError;
  FlutterError.onError = (details) {
    previousFlutter?.call(details);
    unawaited(_report(
        reporter, details.exception, details.stack ?? StackTrace.current,
        fatal: details.library != 'Rider tracking' &&
            details.library != 'Rider notifications'));
  };
  final previousPlatform = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(_report(reporter, error, stack, fatal: true));
    return previousPlatform?.call(error, stack) ?? true;
  };
}

Future<void> _report(
    FirebaseCrashlytics reporter, Object error, StackTrace stack,
    {required bool fatal}) async {
  try {
    await reporter
        .recordError(StateError('Rider ${error.runtimeType}'), stack,
            fatal: fatal, reason: 'Rider runtime failure')
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    // Reporting failure must not crash the app or recurse into error handlers.
  }
}
