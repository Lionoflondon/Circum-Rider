part of './main.dart';

const _riderOfferPushType = 'broadcast-request';
const _riderJobChannelId = 'rider_job_offers';

Future<void> _createRiderNotificationChannel() async {
  const channel = AndroidNotificationChannel(
    _riderJobChannelId,
    'New delivery offers',
    description: 'New delivery offers available for you.',
    importance: Importance.high,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

bool _isOfferMessage(RemoteMessage message) =>
    message.data['type'] == _riderOfferPushType;

Future<void> _routeRiderNotification(RemoteMessage message) async {
  if (!_isOfferMessage(message)) return;
  // The offer feed remains backend-authoritative. A push only opens the feed.
  final navigator = NavKey.navKey.currentState;
  if (navigator == null) return;
  navigator.pushNamedAndRemoveUntil(
    RiderJobOfferScreen.routeName,
    (route) => route.isFirst,
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
    if (message.data['type'] == 'message') {
      final msg = jsonDecode(message.data['data']);
      homeBloc.add(IncomingMessage(data: msg));
      notifyUser(body: msg['message'], title: 'New message');
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
