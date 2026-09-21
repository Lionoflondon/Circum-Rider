import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> requestRiderTrackingNotificationPermission() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await Permission.notification.request();
  }
}

LocationSettings riderLocationSettings() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 8,
      intervalDuration: const Duration(seconds: 5),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Circum Rider location active',
        notificationText: 'Location is being shared for your active delivery.',
        notificationChannelName: 'Active delivery tracking',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }
  return const LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 8,
  );
}
