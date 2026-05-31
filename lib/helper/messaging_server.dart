import 'package:cloud_functions/cloud_functions.dart';

class MessagingServer {
  Future<void> sendMessage({
    required Map<String, String> data,
    required String code,
    required String message,
    String? title,
  }) async {
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    final callable = functions.httpsCallable('sendRiderUpdate');

    await callable.call({
      'token': code,
      'data': data,
      'message': message,
      'title': title,
    });
  }
}
