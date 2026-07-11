import 'package:flutter/material.dart';

import '../communication/rider_communication_service.dart';
import '../communication/rider_conversation_view.dart';
import '../rider_design/rider_ui.dart';

const riderNotificationFilters = [
  'All',
  'Jobs',
  'Deliveries',
  'Messages',
  'Schedule',
  'Earnings',
  'Account',
  'System',
];

class RiderNotificationsView extends StatefulWidget {
  const RiderNotificationsView({
    super.key,
    this.service,
    this.onNavigateTab,
  });

  final RiderCommunicationService? service;
  final ValueChanged<int>? onNavigateTab;

  @override
  State<RiderNotificationsView> createState() => _RiderNotificationsViewState();
}

class _RiderNotificationsViewState extends State<RiderNotificationsView> {
  late final RiderCommunicationService _service;
  var _filter = 'All';
  String? _message;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? RiderCommunicationService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RiderPalette.background,
      body: SafeArea(
        child: StreamBuilder<List<RiderNotificationRecord>>(
          stream: _service.watchNotifications(),
          builder: (context, snapshot) {
            final records = snapshot.data ?? const <RiderNotificationRecord>[];
            final unread = records.where((record) => !record.read).toList();
            final visible = _filter == 'All'
                ? records
                : records
                    .where((record) =>
                        record.category == _categoryForFilter(_filter))
                    .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  unreadCount: unread.length,
                  onBack: () => Navigator.maybePop(context),
                  onMarkAll: unread.isEmpty
                      ? null
                      : () => _guard(() => _service
                          .markAllNotificationsRead(unread.map((n) => n.id))),
                ),
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: riderNotificationFilters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final label = riderNotificationFilters[index];
                      return ChoiceChip(
                        label: Text(label),
                        selected: _filter == label,
                        onSelected: (_) => setState(() => _filter = label),
                        selectedColor: RiderPalette.blue.withValues(alpha: .22),
                        labelStyle: TextStyle(
                          color: _filter == label
                              ? RiderPalette.paper
                              : RiderPalette.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                    child: Text(_message!,
                        style: const TextStyle(
                            color: RiderPalette.amber, fontSize: 12)),
                  ),
                Expanded(
                  child: Builder(builder: (context) {
                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.all(18),
                        child: RiderEmptyState(
                          icon: Icons.notifications_off_outlined,
                          title: 'Notifications unavailable',
                          message: 'Check your connection and try again.',
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (visible.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(18),
                        child: RiderEmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'No notifications yet',
                          message:
                              'Jobs, delivery, message and account updates will appear here.',
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final record = visible[index];
                        return _NotificationCard(
                          record: record,
                          onOpen: () => _openNotification(record),
                          onArchive: () => _guard(
                              () => _service.archiveNotification(record.id)),
                          onDelete: () => _guard(
                              () => _service.deleteNotification(record.id)),
                        );
                      },
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _categoryForFilter(String label) {
    return switch (label) {
      'Jobs' => 'jobs',
      'Deliveries' => 'deliveries',
      'Messages' => 'messages',
      'Schedule' => 'schedule',
      'Earnings' => 'earnings',
      'Account' => 'account',
      _ => 'system',
    };
  }

  Future<void> _openNotification(RiderNotificationRecord record) async {
    await _guard(() => _service.markNotificationRead(record.id));
    if (!mounted) return;
    final destination = record.destination;
    final route = '${destination['route'] ?? ''}'.toLowerCase();
    final chatId =
        '${destination['chatId'] ?? destination['bookingId'] ?? ''}'.trim();
    if ((route == 'conversation' || record.category == 'messages') &&
        chatId.isNotEmpty) {
      Navigator.push(
        context,
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
    final tab = _tabFor(record);
    if (tab != null && widget.onNavigateTab != null) {
      widget.onNavigateTab!(tab);
      Navigator.maybePop(context);
      return;
    }
    setState(() {
      _message = 'This update is no longer available. Showing notifications.';
    });
  }

  int? _tabFor(RiderNotificationRecord record) {
    final route = '${record.destination['route'] ?? ''}'.toLowerCase();
    final category = record.category;
    if (route == 'conversation') return null;
    if (route == 'tracking' ||
        route == 'delivery' ||
        category == 'deliveries') {
      return 1;
    }
    if (route == 'jobs' || category == 'jobs') return 1;
    if (route == 'schedule' || category == 'schedule') return 2;
    if (route == 'wallet' || category == 'earnings') return 3;
    if (route == 'account' || category == 'account') return 4;
    return null;
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _message = null);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Action failed. Check your connection.');
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.unreadCount,
    required this.onBack,
    required this.onMarkAll,
  });

  final int unreadCount;
  final VoidCallback onBack;
  final VoidCallback? onMarkAll;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 14, 10),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: RiderPalette.paper,
            ),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notifications',
                      style: TextStyle(
                          color: RiderPalette.paper,
                          fontFamily: RiderTypography.heading,
                          fontSize: 28)),
                  Text('Jobs, messages and operational updates',
                      style:
                          TextStyle(color: RiderPalette.muted, fontSize: 12)),
                ],
              ),
            ),
            TextButton(
              onPressed: onMarkAll,
              child: Text(unreadCount > 0 ? 'Mark all read' : 'All read'),
            ),
          ],
        ),
      );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.record,
    required this.onOpen,
    required this.onArchive,
    required this.onDelete,
  });

  final RiderNotificationRecord record;
  final VoidCallback onOpen;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => RiderGlassCard(
        padding: const EdgeInsets.all(15),
        onTap: onOpen,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(_icon(record.category), color: RiderPalette.blue, size: 20),
            const SizedBox(width: 9),
            RiderStatusBadge(_label(record.category).toUpperCase(),
                color: record.read ? RiderPalette.muted : RiderPalette.blue),
            const Spacer(),
            if (!record.read)
              const Text('UNREAD',
                  style: TextStyle(
                      color: RiderPalette.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 12),
          Text(record.title,
              style: const TextStyle(
                  color: RiderPalette.paper,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
          if (record.body.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(record.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: RiderPalette.muted, height: 1.35, fontSize: 13)),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Text(_time(record.createdAt),
                style: const TextStyle(
                    color: RiderPalette.muted,
                    fontFamily: RiderTypography.mono,
                    fontSize: 11)),
            const Spacer(),
            IconButton(
              tooltip: 'Archive notification',
              onPressed: onArchive,
              icon: const Icon(Icons.archive_outlined),
              color: RiderPalette.muted,
            ),
            IconButton(
              tooltip: 'Delete notification',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              color: RiderPalette.red,
            ),
          ]),
        ]),
      );

  static String _label(String category) => switch (category) {
        'jobs' => 'Jobs',
        'deliveries' => 'Deliveries',
        'messages' => 'Messages',
        'schedule' => 'Schedule',
        'earnings' => 'Earnings',
        'account' => 'Account',
        _ => 'System',
      };

  static IconData _icon(String category) => switch (category) {
        'jobs' => Icons.work_outline_rounded,
        'deliveries' => Icons.route_rounded,
        'messages' => Icons.chat_bubble_outline_rounded,
        'schedule' => Icons.calendar_month_outlined,
        'earnings' => Icons.account_balance_wallet_outlined,
        'account' => Icons.person_outline_rounded,
        _ => Icons.notifications_none_rounded,
      };

  static String _time(DateTime? value) {
    if (value == null) return 'Time pending';
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
  }
}
