part of './main.dart';

foregoundMessage() {
  // chatBloc.add(event);
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print('Got a message whilst in the foreground!');
    // print('Message data: ${message.data}');
    if (message.data['type'] == 'message') {
      // Parse the modified string into a map
      Map<String, dynamic> msg = jsonDecode(message.data['data']);

      homeBloc.add(IncomingMessage(data: msg));

      await ChatsHelper().storeChat(msg);

      notifyUser(body: msg['message'], title: 'New message');
    }

    if (message.data['type'] == 'broadcast-request') {
      notifyUser(
          body: 'You have a new delivery request waiting!', title: 'Circum');
    }
    return Future<void>.value();
  });
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();

  print('Got a message whilst in the background!');
  print('Message data: ${message.data}');
  if (message.data['type'] == 'message') {
    final msg = jsonDecode(message.data['data']);
    homeBloc.add(IncomingMessage(data: msg));

    await ChatsHelper().storeChat(msg);
    notifyUser(body: msg['message'], title: 'New message');
  }

  if (message.data['type'] == 'broadcast-request') {
    notifyUser(
        body: 'You have a new delivery request waiting!', title: 'Circum');
  }

  return Future<void>.value();
}

void notifyUser({required String title, required String body}) {
  _notificationService.showNotification(
    title: title,
    body: body,
  );
  return;
}
