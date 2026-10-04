// lib/services/notification_service.dart
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';

class NotificationService {
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    final isJob = data['type'] == 'broadcast-request';
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      isJob ? 'rider_job_offers' : 'notifications_updates',
      isJob ? 'New delivery offers' : 'Delivery updates',
      channelDescription: isJob
          ? 'New delivery offers available for you.'
          : 'Delivery, message and account updates.',
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

    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // String notificationContent =
    //     _createStageIndicators(currentStage, totalStages);

    await flutterLocalNotificationsPlugin.show(
      '${data["notificationId"] ?? data["deliveryId"] ?? data["requestId"] ?? title}'
              .hashCode &
          0x7fffffff,
      title,
      body,
      platformChannelSpecifics,
      payload: jsonEncode(data),
    );
  }
}
