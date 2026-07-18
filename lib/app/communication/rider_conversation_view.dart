import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../rider_design/rider_ui.dart';
import 'rider_communication_service.dart';

class RiderConversationView extends StatefulWidget {
  const RiderConversationView({
    super.key,
    required this.chatId,
    required this.title,
    this.subtitle,
    this.service,
  });

  final String chatId;
  final String title;
  final String? subtitle;
  final RiderCommunicationService? service;

  @override
  State<RiderConversationView> createState() => _RiderConversationViewState();
}

class _RiderConversationViewState extends State<RiderConversationView> {
  late final RiderCommunicationService _service;
  late final RiderTypingController _typing;
  late Stream<RiderConversationSnapshot> _conversation;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Future<void> _draftWrites = Future<void>.value();
  var _sending = false;
  var _readMarked = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? RiderCommunicationService();
    _typing = RiderTypingController(chatId: widget.chatId, service: _service);
    _conversation = _service.watchConversation(widget.chatId);
    _restoreDraft();
  }

  @override
  void dispose() {
    _typing.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _service.sendText(chatId: widget.chatId, message: text);
      _input.clear();
      await _clearDraft();
      _typing.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    } catch (error) {
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String get _draftKey => 'rider_conversation_draft_${widget.chatId}';

  Future<void> _restoreDraft() async {
    final preferences = await SharedPreferences.getInstance();
    final draft = preferences.getString(_draftKey)?.trim() ?? '';
    if (!mounted || draft.isEmpty || _input.text.isNotEmpty) return;
    _input.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
    setState(() {});
  }

  void _saveDraft(String value) {
    _draftWrites = _draftWrites.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      final draft = value.trim();
      if (draft.isEmpty) {
        await preferences.remove(_draftKey);
      } else {
        await preferences.setString(_draftKey, value);
      }
    });
  }

  Future<void> _clearDraft() async {
    await _draftWrites;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_draftKey);
  }

  void _onDraftChanged(String value) {
    _typing.textChanged(value);
    _saveDraft(value);
  }

  void _retryConversation() {
    setState(() {
      _conversation = _service.watchConversation(widget.chatId);
      _readMarked = false;
    });
  }

  void _markReadOnce() {
    if (_readMarked) return;
    _readMarked = true;
    _service.markRead(widget.chatId).catchError((_) {});
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: RiderPalette.background,
      body: SafeArea(
        child: Column(
          children: [
            _ConversationHeader(
              title: widget.title,
              subtitle: widget.subtitle ?? widget.chatId,
            ),
            Expanded(
              child: StreamBuilder<RiderConversationSnapshot>(
                stream: _conversation,
                builder: (context, snapshot) {
                  if (snapshot.hasData) _markReadOnce();
                  if (snapshot.hasError) {
                    return _ConversationLoadError(
                      onRetry: _retryConversation,
                    );
                  }
                  if (!snapshot.hasData) {
                    return const _ConversationLoading();
                  }
                  final conversation = snapshot.data!;
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _scrollToEnd());
                  return Column(
                    children: [
                      Expanded(
                        child: conversation.messages.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(18),
                                child: RiderEmptyState(
                                  icon: Icons.forum_outlined,
                                  title: 'No messages yet',
                                  message:
                                      'Delivery messages and Circum Support updates will appear here.',
                                ),
                              )
                            : ListView.separated(
                                controller: _scroll,
                                padding:
                                    const EdgeInsets.fromLTRB(18, 18, 18, 20),
                                itemCount: conversation.messages.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) => _MessageBubble(
                                  message: conversation.messages[index],
                                  currentUid:
                                      FirebaseAuth.instance.currentUser?.uid,
                                ),
                              ),
                      ),
                      if (conversation.typingUserIds.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Typing...',
                              style: TextStyle(
                                color: RiderPalette.muted,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: RiderPalette.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _sending ? null : _send,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      _Composer(
                        readOnly: conversation.readOnly,
                        controller: _input,
                        sending: _sending,
                        onChanged: _onDraftChanged,
                        onSend: _send,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _friendlyError(Object error) {
    final text = '$error';
    if (text.contains('read-only')) {
      return 'This conversation is read-only because the delivery is complete.';
    }
    if (text.contains('not-found')) {
      return 'This conversation is not available yet.';
    }
    if (text.contains('permission-denied')) {
      return 'You do not have access to this conversation.';
    }
    return 'Message failed. Check your connection and retry.';
  }
}

class _ConversationLoading extends StatelessWidget {
  const _ConversationLoading();

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          label: 'Loading support conversation',
          liveRegion: true,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text(
                'Loading conversation...',
                style: TextStyle(color: RiderPalette.muted),
              ),
            ],
          ),
        ),
      );
}

class _ConversationLoadError extends StatelessWidget {
  const _ConversationLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const RiderEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Conversation unavailable',
              message:
                  'We could not load this conversation. Check your connection and try again.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: RiderGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                color: RiderPalette.paper,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: RiderPalette.paper,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: RiderPalette.muted, fontSize: 12)),
                  ],
                ),
              ),
              const RiderStatusBadge('SECURE', color: RiderPalette.blue),
            ],
          ),
        ),
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.currentUid});

  final RiderConversationMessage message;
  final String? currentUid;

  @override
  Widget build(BuildContext context) {
    final mine = message.senderId == currentUid;
    final system = message.isSystem;
    final admin = message.isAdmin;
    if (system) {
      return Center(
        child: RiderStatusBadge(
          message.text.isEmpty ? 'System update' : message.text,
          color: RiderPalette.muted,
        ),
      );
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Semantics(
        label:
            '${mine ? 'Your message' : admin ? 'Circum Support message' : 'Delivery message'}: ${message.text}',
        child: Container(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .72),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: mine
                ? RiderPalette.blue.withValues(alpha: .88)
                : admin
                    ? RiderPalette.purple.withValues(alpha: .18)
                    : Colors.white.withValues(alpha: .07),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(17),
              topRight: const Radius.circular(17),
              bottomLeft: Radius.circular(mine ? 17 : 4),
              bottomRight: Radius.circular(mine ? 4 : 17),
            ),
            border: Border.all(
              color: admin
                  ? RiderPalette.purple.withValues(alpha: .35)
                  : Colors.white.withValues(alpha: .09),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (admin) ...[
                const Text('Circum Support',
                    style: TextStyle(
                        color: RiderPalette.paper,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
              ],
              Text(message.text,
                  style:
                      const TextStyle(color: RiderPalette.paper, height: 1.35)),
              const SizedBox(height: 6),
              Text(_time(message.createdAt),
                  style: TextStyle(
                      color: RiderPalette.paper.withValues(alpha: .62),
                      fontSize: 10,
                      fontFamily: RiderTypography.mono)),
            ],
          ),
        ),
      ),
    );
  }

  static String _time(DateTime? value) {
    if (value == null) return 'Sending';
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.readOnly,
    required this.controller,
    required this.sending,
    required this.onChanged,
    required this.onSend,
  });

  final bool readOnly;
  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: RiderGlassCard(
          padding: const EdgeInsets.all(10),
          child: readOnly
              ? const Text(
                  'This delivery is complete. Conversation history remains available for reference.',
                  style: TextStyle(color: RiderPalette.muted, height: 1.35),
                )
              : Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        onChanged: onChanged,
                        style: const TextStyle(color: RiderPalette.paper),
                        decoration: const InputDecoration(
                          hintText: 'Message',
                          hintStyle: TextStyle(color: RiderPalette.muted),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Send message',
                      child: IconButton.filled(
                        onPressed: sending ? null : onSend,
                        icon: sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.arrow_upward_rounded),
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: RiderPalette.blue,
                          minimumSize: const Size(44, 44),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      );
}
