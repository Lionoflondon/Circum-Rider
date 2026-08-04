part of './main.dart';

foregoundMessage() {
  // chatBloc.add(event);
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    if (message.data['type'] == 'message') {
      final msg = _decodeRiderCommunicationPayload(
        message,
        expectedType: 'message',
        stage: 'foreground',
      );
      if (msg == null) return;

      homeBloc.add(IncomingMessage(data: msg));

      notifyUser(body: msg['message'], title: 'New message');
    }

    if (message.data['type'] == 'broadcast-request') {
      homeBloc.add(GetAvailableRequests());
      homeBloc.add(SetDrawerHeight(
          minDrawerHeight: homeBloc.state.minDrawerHeight,
          maxDrawerHeight: 0.75.sh));
      homeBloc.add(SetPanelControlStatus(status: PanelControlStatus.isOpened));
      notifyUser(
          body: 'You have a new delivery request waiting!', title: 'Circum');
    }
    return Future<void>.value();
  });
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();

  if (message.data['type'] == 'message') {
    final msg = _decodeRiderCommunicationPayload(
      message,
      expectedType: 'message',
      stage: 'background',
    );
    if (msg == null) return Future<void>.value();
    homeBloc.add(IncomingMessage(data: msg));

    notifyUser(body: msg['message'], title: 'New message');
  }

  if (message.data['type'] == 'broadcast-request') {
    homeBloc.add(GetAvailableRequests());
    notifyUser(
        body: 'You have a new delivery request waiting!', title: 'Circum');
  }

  return Future<void>.value();
}

Map<String, dynamic>? _decodeRiderCommunicationPayload(
  RemoteMessage message, {
  required String expectedType,
  required String stage,
}) {
  try {
    final data = message.data['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    final jsonString = '${data ?? ''}'.trim();
    if (jsonString.isEmpty) {
      _logRecoverableRiderPushPayload(
        expectedType: expectedType,
        stage: stage,
        reason: 'missing_data',
        messageId: message.messageId,
      );
      return null;
    }
    final decoded = jsonDecode(jsonString.replaceAll("'", '"'));
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    _logRecoverableRiderPushPayload(
      expectedType: expectedType,
      stage: stage,
      reason: 'data_not_map',
      messageId: message.messageId,
    );
  } catch (error, stackTrace) {
    _logRecoverableRiderPushPayload(
      expectedType: expectedType,
      stage: stage,
      reason: 'decode_failed',
      messageId: message.messageId,
      error: error,
      stackTrace: stackTrace,
    );
  }
  return null;
}

void _logRecoverableRiderPushPayload({
  required String expectedType,
  required String stage,
  required String reason,
  String? messageId,
  Object? error,
  StackTrace? stackTrace,
}) {
  developer.log(
    'Recoverable Rider push payload discarded: '
    'type=$expectedType stage=$stage reason=$reason messageId=${messageId ?? 'unknown'}'
    '${error == null ? '' : ' error=$error'}',
    name: 'circum.rider.messaging',
    error: error,
    stackTrace: stackTrace,
  );
}

void notifyUser({required String title, required String body}) {
  _notificationService.showNotification(
    title: title,
    body: body,
  );
  return;
}
