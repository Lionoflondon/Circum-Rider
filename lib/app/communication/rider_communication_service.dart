import 'package:circum_rider/app/rider_callable_api.dart';
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
    Future<dynamic> Function(String, Map<String, dynamic>)? callable,
  })  : _callable = callable,
        firestore = firestore ?? FirebaseFirestore.instance,
        functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
        auth = auth ?? FirebaseAuth.instance;

  final Future<dynamic> Function(String, Map<String, dynamic>)? _callable;
  Future<dynamic> _call(String name, Map<String, dynamic> data) async {
    if (_callable != null) return _callable(name, data);
    return (await functions.riderCallable(name).call(data)).data;
  }

  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final FirebaseAuth auth;

  Stream<RiderConversationSnapshot> watchConversation(String chatId,
      {int limit = 80}) {
    final chat = firestore.collection('chats').doc(chatId);
    return Stream<RiderConversationSnapshot>.multi((output) {
      Map<String, dynamic>? metadata;
      List<RiderConversationMessage>? messages;
      void publish() {
        if (metadata == null || messages == null) return;
        final data = metadata!;
        final typing = data['typing'] is Map
            ? Map<String, dynamic>.from(data['typing'])
            : <String, dynamic>{};
        final now = DateTime.now().millisecondsSinceEpoch;
        output.add(RiderConversationSnapshot(
            chatId: chatId,
            readOnly: data['readOnly'] == true,
            messages: messages!,
            typingUserIds: typing.entries
                .where((e) =>
                    e.key != auth.currentUser?.uid &&
                    e.value is num &&
                    e.value > now)
                .map((e) => e.key)
                .toList(),
            unreadBy: data['unreadBy'] is Iterable
                ? (data['unreadBy'] as Iterable).map((e) => '$e').toList()
                : const []));
      }

      final chatSubscription = chat.snapshots().listen((snapshot) {
        metadata = snapshot.data() ?? {};
        publish();
      }, onError: output.addError);
      final query =
          chat.collection('messages').orderBy('createdAt', descending: true);
      final messageSubscription =
          query.limit(80).snapshots().asyncMap((head) async {
        final documents = [...head.docs];
        var page = head.docs;
        while (documents.length < limit && page.length == 80) {
          final next =
              await query.startAfterDocument(page.last).limit(80).get();
          page = next.docs;
          documents.addAll(page);
        }
        return documents.take(limit).toList();
      }).listen((documents) {
        messages = documents.reversed
            .map(RiderConversationMessage.fromDocument)
            .where((message) => message.text.isNotEmpty || message.isSystem)
            .toList();
        publish();
      }, onError: output.addError);
      output.onCancel = () async {
        await chatSubscription.cancel();
        await messageSubscription.cancel();
      };
    });
  }

  Future<void> sendText({
    required String chatId,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    await _call('sendCircumMessage', {
      'chatId': chatId,
      'message': trimmed,
      'messageType': 'text',
    });
  }

  Future<void> setTyping({
    required String chatId,
    required bool typing,
  }) async {
    await _call('setConversationTyping', {
      'chatId': chatId,
      'typing': typing,
    });
  }

  Future<void> markRead(String chatId) async {
    await functions
        .riderCallable('markConversationRead')
        .call({'chatId': chatId});
  }

  Stream<List<RiderNotificationRecord>> watchNotifications({int limit = 100}) {
    final uid = auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    final query = firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);
    return query.limit(100).snapshots().asyncMap((head) async {
      final documents = [...head.docs];
      var page = head.docs;
      while (documents.length < limit && page.length == 100) {
        final next = await query.startAfterDocument(page.last).limit(100).get();
        page = next.docs;
        documents.addAll(page);
      }
      if (auth.currentUser?.uid != uid) return <RiderNotificationRecord>[];
      final unique = <String, RiderNotificationRecord>{};
      for (final doc in documents.take(limit)) {
        final record = RiderNotificationRecord.fromDocument(doc);
        if (!record.archived && !record.deleted) unique[record.id] = record;
      }
      return unique.values.toList();
    });
  }

  Stream<int?> watchUnreadNotificationCount() {
    return watchNotifications().map(
      (records) => records.where((record) => !record.read).length,
    );
  }

  Future<void> markNotificationRead(String id) =>
      _updateNotificationState([id], 'mark_read');

  Future<void> markAllNotificationsRead(Iterable<String> ids) =>
      _updateNotificationState(ids, 'mark_read');

  Future<void> archiveNotification(String id) =>
      _updateNotificationState([id], 'archive');

  Future<void> deleteNotification(String id) =>
      _updateNotificationState([id], 'delete');

  Future<void> _updateNotificationState(
      Iterable<String> ids, String action) async {
    final notificationIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    // The callable accepts at most 100 notification IDs per transaction.
    for (var offset = 0; offset < notificationIds.length; offset += 100) {
      await _call('updateRiderNotificationState', {
        'notificationIds': notificationIds.skip(offset).take(100).toList(),
        'action': action,
      }).timeout(const Duration(seconds: 20));
    }
  }
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
