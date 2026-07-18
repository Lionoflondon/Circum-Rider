import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ChatsHelper {
  @Deprecated(
      'Use the canonical communication engine. This helper is read-only compatibility only.')
  Future<bool> storeChat(message) async {
    return false;
  }

  Future<List<dynamic>> readStoredChat(String requestId) async {
    if (requestId.trim().isEmpty) return const [];
    try {
      final directory = await getApplicationDocumentsDirectory();
      final chats = File('${directory.path}/$requestId.json');
      if (!await chats.exists()) return const [];
      final contents = await chats.readAsString();
      final parsed = jsonDecode(contents);
      return parsed is List ? parsed : const [];
    } catch (_) {
      return const [];
    }
  }
}
