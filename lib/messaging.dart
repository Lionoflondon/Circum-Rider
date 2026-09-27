part of './main.dart';

const _riderOfferPushType = 'broadcast-request';
const _riderJobChannelId = 'rider_job_offers';

Future<void> _createRiderNotificationChannel() async {
  const channels = [
    AndroidNotificationChannel(
      _riderJobChannelId,
      'New delivery offers',
      description: 'New delivery offers available for you.',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'notifications_updates',
      'Delivery updates',
      description: 'Delivery, message and account updates.',
      importance: Importance.high,
    ),
  ];
  final android =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  for (final channel in channels) {
    await android?.createNotificationChannel(channel);
  }
}

bool _isOfferMessage(RemoteMessage message) =>
    message.data['type'] == _riderOfferPushType;

bool _isChatNotification(RemoteMessage message) =>
    message.data['type'] == 'message' ||
    message.data['notificationType'] == 'chat_message' ||
    message.data['route'] == 'conversation';

String _notificationChatId(RemoteMessage message) {
  final direct = message.data['chatId'] ??
      message.data['bookingId'] ??
      message.data['requestId'];
  if (direct != null && '$direct'.trim().isNotEmpty) return '$direct'.trim();
  final encoded = message.data['data'];
  if (encoded is String) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map) {
        return '${decoded['chatId'] ?? decoded['requestId'] ?? ''}'.trim();
      }
    } catch (_) {
      // A malformed legacy payload is safely handled by the notification centre.
    }
  }
  return '';
}

Future<void> _routeRiderNotification(RemoteMessage message) async {
  // The offer feed remains backend-authoritative. A push only opens the feed.
  final navigator = NavKey.navKey.currentState;
  if (navigator == null) return;
  if (_isOfferMessage(message)) {
    navigator.pushNamedAndRemoveUntil(
      RiderJobOfferScreen.routeName,
      (route) => route.isFirst,
    );
    return;
  }
  final route = '${message.data['route'] ?? ''}'.toLowerCase();
  final chatId = _notificationChatId(message);
  if ((route == 'conversation' || _isChatNotification(message)) &&
      chatId.isNotEmpty) {
    navigator.push(
      MaterialPageRoute(
        builder: (_) => RiderConversationView(
          chatId: chatId,
          title: 'Delivery chat',
          subtitle: 'Opened from notification',
        ),
      ),
    );
    return;
  }
  navigator.push(
    MaterialPageRoute(builder: (_) => const RiderNotificationsView()),
  );
}

void _configureRiderNotificationOpenRouting() {
  FirebaseMessaging.onMessageOpenedApp.listen(_routeRiderNotification);
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message == null) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _routeRiderNotification(message),
    );
  });
}

void foregoundMessage() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    if (_isChatNotification(message)) {
      final encoded = message.data['data'];
      if (message.data['type'] == 'message' && encoded is String) {
        try {
          final msg = jsonDecode(encoded);
          if (msg is Map) homeBloc.add(IncomingMessage(data: msg));
        } catch (_) {
          // The notification centre remains the safe source for malformed data.
        }
      }
      notifyUser(
        body: message.notification?.body ?? 'You have a new message.',
        title: message.notification?.title ?? 'New message',
      );
      return;
    }
    if (_isOfferMessage(message)) {
      homeBloc.add(GetAvailableRequests());
      homeBloc.add(
        SetDrawerHeight(
          minDrawerHeight: homeBloc.state.minDrawerHeight,
          maxDrawerHeight: 0.75.sh,
        ),
      );
      homeBloc.add(SetPanelControlStatus(status: PanelControlStatus.isOpened));
      notifyUser(
        body: 'You have a new delivery request waiting!',
        title: 'Circum',
      );
      return;
    }
    if (message.notification != null || message.data.isNotEmpty) {
      notifyUser(
        body: message.notification?.body ?? 'You have a new Circum update.',
        title: message.notification?.title ?? 'Circum Rider',
      );
    }
  });
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // A background isolate must not use UI blocs or foreground-only plugins.
  // FCM renders the server notification; the tap route reloads offers safely.
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  if (!_isOfferMessage(message)) return;
  return;
}

void notifyUser({required String title, required String body}) {
  _notificationService.showNotification(title: title, body: body);
}
