// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  const NotificationService(this.plugin);

  final FlutterLocalNotificationsPlugin plugin;

  Future<void> showNotification(
      {required String title, required String body}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'notifications_updates',
      'Notifications Updates',
      channelDescription: 'Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // String notificationContent =
    //     _createStageIndicators(currentStage, totalStages);

    await plugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );
  }
}
