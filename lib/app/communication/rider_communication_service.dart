import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RiderConversationMessage {
  const RiderConversationMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.senderRole,
    required this.messageType,
    required this.readBy,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;
  final String senderRole;
  final String messageType;
  final List<String> readBy;

  bool get isSystem => messageType == 'system' || senderRole == 'system';
  bool get isAdmin => senderRole == 'admin';

  factory RiderConversationMessage.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final created = data['createdAt'];
    return RiderConversationMessage(
      id: document.id,
      senderId: '${data['senderId'] ?? ''}',
      text: '${data['messageText'] ?? data['message'] ?? ''}'.trim(),
      createdAt: created is Timestamp ? created.toDate() : null,
      senderRole: '${data['senderRole'] ?? ''}'.trim().toLowerCase(),
      messageType: '${data['messageType'] ?? 'text'}'.trim().toLowerCase(),
      readBy: data['readBy'] is Iterable
          ? List<String>.from(
              (data['readBy'] as Iterable).map((item) => '$item'))
          : const [],
    );
  }
}

class RiderConversationSnapshot {
  const RiderConversationSnapshot({
    required this.chatId,
    required this.readOnly,
    required this.messages,
    required this.typingUserIds,
    required this.unreadBy,
  });

  final String chatId;
  final bool readOnly;
  final List<RiderConversationMessage> messages;
  final List<String> typingUserIds;
  final List<String> unreadBy;
}

class RiderNotificationRecord {
  const RiderNotificationRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.read,
    required this.archived,
    required this.deleted,
    required this.createdAt,
    required this.destination,
    required this.type,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final bool read;
  final bool archived;
  final bool deleted;
  final DateTime? createdAt;
  final Map<String, dynamic> destination;
  final String type;

  factory RiderNotificationRecord.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final destination = data['destination'] is Map
        ? Map<String, dynamic>.from(data['destination'] as Map)
        : data['data'] is Map && (data['data'] as Map)['destination'] is Map
            ? Map<String, dynamic>.from(
                (data['data'] as Map)['destination'] as Map)
            : const <String, dynamic>{};
    final created = data['createdAt'] ?? data['timestamp'];
    return RiderNotificationRecord(
      id: document.id,
      title: '${data['title'] ?? 'Circum update'}'.trim(),
      body: '${data['body'] ?? data['message'] ?? ''}'.trim(),
      category: normalizeNotificationCategory(
        '${data['category'] ?? data['type'] ?? ''}',
      ),
      read: data['read'] == true || data['isRead'] == true,
      archived: data['archived'] == true,
      deleted: data['deletedAt'] != null,
      createdAt: created is Timestamp ? created.toDate() : null,
      destination: destination,
      type: '${data['type'] ?? ''}'.trim(),
    );
  }
}

String normalizeNotificationCategory(String raw) {
  final value = raw.trim().toLowerCase();
  if (value.contains('job') || value == 'new_delivery') return 'jobs';
  if (value.contains('message') || value.contains('chat')) return 'messages';
  if (value.contains('schedule')) return 'schedule';
  if (value.contains('earning') ||
      value.contains('payout') ||
      value.contains('wallet') ||
      value.contains('roth')) {
    return 'earnings';
  }
  if (value.contains('account') ||
      value.contains('document') ||
      value.contains('profile') ||
      value.contains('approval')) {
    return 'account';
  }
  if (value.contains('delivery') || value.contains('tracking')) {
    return 'deliveries';
  }
  return 'system';
}

class RiderCommunicationService {
  RiderCommunicationService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
        auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final FirebaseAuth auth;

  Stream<RiderConversationSnapshot> watchConversation(String chatId) {
    final chat = firestore.collection('chats').doc(chatId);
    final controller = StreamController<RiderConversationSnapshot>();
    DocumentSnapshot<Map<String, dynamic>>? latestChat;
    QuerySnapshot<Map<String, dynamic>>? latestMessages;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? chatSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? messageSub;

    void emitIfReady() {
      final chatSnapshot = latestChat;
      final messageSnapshot = latestMessages;
      if (chatSnapshot == null || messageSnapshot == null) return;
      final data = chatSnapshot.data() ?? const <String, dynamic>{};
      final now = DateTime.now().millisecondsSinceEpoch;
      final typing = data['typing'] is Map
          ? Map<String, dynamic>.from(data['typing'] as Map)
          : const <String, dynamic>{};
      controller.add(RiderConversationSnapshot(
        chatId: chatId,
        readOnly: data['readOnly'] == true,
        messages: messageSnapshot.docs
            .map(RiderConversationMessage.fromDocument)
            .where((message) => message.text.isNotEmpty || message.isSystem)
            .toList(),
        typingUserIds: typing.entries
            .where((entry) => entry.key != auth.currentUser?.uid)
            .where((entry) => entry.value is num && (entry.value as num) > now)
            .map((entry) => entry.key)
            .toList(),
        unreadBy: data['unreadBy'] is Iterable
            ? List<String>.from(
                (data['unreadBy'] as Iterable).map((item) => '$item'))
            : const [],
      ));
    }

    controller.onListen = () {
      chatSub = chat.snapshots().listen((snapshot) {
        latestChat = snapshot;
        emitIfReady();
      }, onError: controller.addError);
      messageSub = chat
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .limit(80)
          .snapshots()
          .listen((snapshot) {
        latestMessages = snapshot;
        emitIfReady();
      }, onError: controller.addError);
    };
    controller.onCancel = () async {
      await chatSub?.cancel();
      await messageSub?.cancel();
    };
    return controller.stream;
  }

  Future<void> sendText({
    required String chatId,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    await functions.httpsCallable('sendCircumMessage').call({
      'chatId': chatId,
      'message': trimmed,
      'messageType': 'text',
    });
  }

  Future<void> setTyping({
    required String chatId,
    required bool typing,
  }) async {
    await functions.httpsCallable('setConversationTyping').call({
      'chatId': chatId,
      'typing': typing,
    });
  }

  Future<void> markRead(String chatId) async {
    await functions
        .httpsCallable('markConversationRead')
        .call({'chatId': chatId});
  }

  Stream<List<RiderNotificationRecord>> watchNotifications() {
    final uid = auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      final records = snapshot.docs
          .map(RiderNotificationRecord.fromDocument)
          .where((record) => !record.archived && !record.deleted)
          .toList();
      return records;
    });
  }

  Stream<int?> watchUnreadNotificationCount() {
    return watchNotifications().map(
      (records) => records.where((record) => !record.read).length,
    );
  }

  Future<void> markNotificationRead(String id) =>
      functions.httpsCallable('updateRiderNotificationState').call({
        'notificationId': id,
        'action': 'mark_read',
      });

  Future<void> markAllNotificationsRead(Iterable<String> ids) async {
    final notificationIds = ids.where((id) => id.trim().isNotEmpty).toList();
    if (notificationIds.isEmpty) return;
    await functions.httpsCallable('updateRiderNotificationState').call({
      'notificationIds': notificationIds,
      'action': 'mark_read',
    });
  }

  Future<void> archiveNotification(String id) =>
      functions.httpsCallable('updateRiderNotificationState').call({
        'notificationId': id,
        'action': 'archive',
      });

  Future<void> deleteNotification(String id) =>
      functions.httpsCallable('updateRiderNotificationState').call({
        'notificationId': id,
        'action': 'delete',
      });
}

class RiderTypingController {
  RiderTypingController({
    required this.chatId,
    required this.service,
    this.debounce = const Duration(milliseconds: 900),
    this.idle = const Duration(seconds: 4),
  });

  final String chatId;
  final RiderCommunicationService service;
  final Duration debounce;
  final Duration idle;
  Timer? _startTimer;
  Timer? _stopTimer;
  bool _typing = false;

  void textChanged(String value) {
    final hasText = value.trim().isNotEmpty;
    _startTimer?.cancel();
    _stopTimer?.cancel();
    if (!hasText) {
      clear();
      return;
    }
    if (!_typing) {
      _startTimer = Timer(debounce, () {
        _typing = true;
        service.setTyping(chatId: chatId, typing: true);
      });
    }
    _stopTimer = Timer(idle, clear);
  }

  void clear() {
    _startTimer?.cancel();
    _stopTimer?.cancel();
    if (_typing) {
      _typing = false;
      service.setTyping(chatId: chatId, typing: false);
    }
  }

  void dispose() => clear();
}
