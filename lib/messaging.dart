part of './main.dart';

String? _lastOpenedNotification;
DateTime? _lastOpenedAt;

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

const _riderOpenStorage = FlutterSecureStorage();
final _pendingRiderOpens = RiderPendingOpen<RemoteMessage>(
  ready: () => NavKey.navKey.currentState != null,
  account: () => FirebaseAuth.instance.currentUser?.uid,
  open: (message) async {
    await _openRiderNotification(message);
    unawaited(_recordRiderPushReceipt(message, 'mark_opened'));
  },
  read: () => _riderOpenStorage
      .read(key: 'rider_pending_notification_opens')
      .timeout(const Duration(seconds: 3)),
  write: (value) => _riderOpenStorage
      .write(key: 'rider_pending_notification_opens', value: value)
      .timeout(const Duration(seconds: 3)),
  encode: (message) => {
    'data': riderPendingPushData(message.data),
    'messageId': message.messageId
  },
  decode: (value) {
    final stored = Map<String, dynamic>.from(value as Map);
    return RemoteMessage(
        data: Map<String, dynamic>.from(stored['data'] as Map),
        messageId: stored['messageId'] as String?);
  },
  onError: (_) => FlutterError.reportError(FlutterErrorDetails(
    exception: StateError('Rider notification target could not be opened'),
    library: 'Rider notifications',
  )),
);

Future<void> _routeRiderNotification(RemoteMessage message) async {
  await _pendingRiderOpens.add(message);
}

Future<void> _openRiderNotification(RemoteMessage message) async {
  final navigator = NavKey.navKey.currentState;
  if (navigator == null) return;
  final notificationId =
      '${message.data['notificationId'] ?? message.messageId ?? ''}';
  final now = DateTime.now();
  if (notificationId.isNotEmpty &&
      notificationId == _lastOpenedNotification &&
      _lastOpenedAt != null &&
      now.difference(_lastOpenedAt!) < const Duration(seconds: 2)) return;
  _lastOpenedNotification = notificationId;
  _lastOpenedAt = now;
  if (_isOfferMessage(message)) {
    final id = riderOfferId(message.data);
    if (id == null) {
      navigator.push(
          MaterialPageRoute(builder: (_) => const RiderNotificationsView()));
    } else {
      navigator.push(MaterialPageRoute(
          builder: (_) => RiderJobOfferScreen(initialDeliveryId: id)));
    }
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
  final target = RiderNotificationTarget.fromDestination(
      Map<String, dynamic>.from(message.data));
  if (target != null) {
    navigator.push(MaterialPageRoute(
        builder: (_) => RiderNotificationEntityView(target: target)));
    return;
  }
  navigator.push(
    MaterialPageRoute(builder: (_) => const RiderNotificationsView()),
  );
}

Future<void> _configureRiderNotificationOpenRouting() async {
  await _pendingRiderOpens.restore();
  FirebaseMessaging.onMessageOpenedApp.listen(_routeRiderNotification);
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message == null) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _routeRiderNotification(message),
    );
  });
}

Future<void> _recordRiderPushReceipt(
    RemoteMessage message, String action) async {
  final id = '${message.data['notificationId'] ?? ''}'.trim();
  if (id.isEmpty ||
      id.contains('/') ||
      FirebaseAuth.instance.currentUser == null) return;
  try {
    await FirebaseFunctions.instanceFor(region: 'us-central1')
        .riderCallable('updateRiderNotificationState')
        .call({'notificationId': id, 'action': action}).timeout(
            const Duration(seconds: 10));
  } catch (_) {
    FlutterError.reportError(FlutterErrorDetails(
        exception: StateError('Rider push receipt could not be recorded'),
        library: 'Rider notifications'));
  }
}

void foregoundMessage() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    unawaited(_recordRiderPushReceipt(message, 'mark_received'));
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
        data: message.data,
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
        data: message.data,
      );
      return;
    }
    if (message.notification != null || message.data.isNotEmpty) {
      notifyUser(
        body: message.notification?.body ?? 'You have a new Circum update.',
        title: message.notification?.title ?? 'Circum Rider',
        data: message.data,
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

void notifyUser(
    {required String title,
    required String body,
    Map<String, dynamic> data = const {}}) {
  _notificationService.showNotification(title: title, body: body, data: data);
}
