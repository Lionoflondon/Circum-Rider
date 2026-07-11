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
            final grouped = _groupNotifications(visible);
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
                  height: 50,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        backgroundColor: Colors.white.withValues(alpha: .045),
                        side: BorderSide(
                          color: _filter == label
                              ? RiderPalette.blue.withValues(alpha: .30)
                              : Colors.white.withValues(alpha: .08),
                        ),
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
                        child: _NotificationEmptyState(
                          icon: Icons.notifications_off_outlined,
                          title: 'Notifications unavailable',
                          message: 'Check your connection and try again.',
                          accent: RiderPalette.amber,
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(
                        color: RiderPalette.blue,
                      ));
                    }
                    if (visible.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(18),
                        child: _NotificationEmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'No notifications yet',
                          message:
                              'Jobs, delivery, message and account updates will appear here.',
                          accent: RiderPalette.blue,
                        ),
                      );
                    }
                    return RefreshIndicator(
                      color: RiderPalette.blue,
                      backgroundColor: RiderPalette.panel,
                      onRefresh: () async => setState(() {}),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        children: [
                          for (final group in grouped.entries) ...[
                            _DayGroup(
                              label: group.key,
                              children: [
                                for (final record in group.value)
                                  _NotificationCard(
                                    record: record,
                                    onOpen: () => _openNotification(record),
                                    onArchive: () => _guard(() => _service
                                        .archiveNotification(record.id)),
                                    onDelete: () => _guard(() =>
                                        _service.deleteNotification(record.id)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ],
                      ),
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

  Map<String, List<RiderNotificationRecord>> _groupNotifications(
    List<RiderNotificationRecord> records,
  ) {
    final grouped = <String, List<RiderNotificationRecord>>{
      'Today': <RiderNotificationRecord>[],
      'Yesterday': <RiderNotificationRecord>[],
      'Earlier': <RiderNotificationRecord>[],
    };
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    for (final record in records) {
      final createdAt = record.createdAt;
      if (createdAt == null) {
        grouped['Earlier']!.add(record);
        continue;
      }
      final local = createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (day == today) {
        grouped['Today']!.add(record);
      } else if (day == yesterday) {
        grouped['Yesterday']!.add(record);
      } else {
        grouped['Earlier']!.add(record);
      }
    }
    grouped.removeWhere((_, records) => records.isEmpty);
    return grouped;
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
        padding: const EdgeInsets.fromLTRB(12, 8, 18, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: RiderPalette.paper,
            ),
            const Expanded(
              child: Text(
                'Notifications',
                style: TextStyle(
                  color: RiderPalette.paper,
                  fontFamily: RiderTypography.heading,
                  fontSize: 27,
                  height: 1,
                ),
              ),
            ),
            TextButton(
              onPressed: onMarkAll,
              child: Text(
                unreadCount > 0 ? 'Mark all read' : 'All read',
                style: TextStyle(
                  color: unreadCount > 0
                      ? RiderPalette.blue
                      : RiderPalette.muted.withValues(alpha: .58),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
}

class _DayGroup extends StatelessWidget {
  const _DayGroup({
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: RiderPalette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .9,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
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
  Widget build(BuildContext context) {
    final accent = _accent(record.category, record.type);
    final unread = !record.read;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label:
            '${unread ? 'Unread ' : ''}${_label(record.category)} notification. ${record.title}',
        child: Stack(
          children: [
            RiderGlassSurface(
              radius: 18,
              blur: 10,
              opacity: unread ? .58 : .50,
              edgeColor: unread ? RiderPalette.blue : accent,
              padding: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 14, 10, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accent.withValues(alpha: .24),
                          ),
                        ),
                        child: Icon(
                          _icon(record.category),
                          color: accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    record.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: RiderPalette.paper,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _time(record.createdAt),
                                  style: const TextStyle(
                                    color: RiderPalette.muted,
                                    fontFamily: RiderTypography.mono,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                            if (record.body.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                record.body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: RiderPalette.muted,
                                  height: 1.45,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  _label(record.category),
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                _ActionIcon(
                                  label: 'Archive notification',
                                  icon: Icons.archive_outlined,
                                  color: RiderPalette.muted,
                                  onPressed: onArchive,
                                ),
                                _ActionIcon(
                                  label: 'Delete notification',
                                  icon: Icons.delete_outline_rounded,
                                  color: RiderPalette.red,
                                  onPressed: onDelete,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (unread)
              Positioned(
                left: 0,
                top: 14,
                bottom: 14,
                child: Container(
                  width: 3,
                  decoration: const BoxDecoration(
                    color: RiderPalette.blue,
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(3),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

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

  static Color _accent(String category, String type) {
    final value = type.toLowerCase();
    if (value.contains('failed') ||
        value.contains('rejected') ||
        value.contains('suspension') ||
        value.contains('critical')) {
      return RiderPalette.red;
    }
    if (value.contains('expiring') ||
        value.contains('waiting') ||
        value.contains('restriction') ||
        value.contains('required')) {
      return RiderPalette.amber;
    }
    if (value.contains('approved') ||
        value.contains('completed') ||
        value.contains('sent') ||
        value.contains('paid') ||
        value.contains('reactivation')) {
      return RiderPalette.green;
    }
    if (value.contains('vanguard') ||
        value.contains('rank') ||
        value.contains('trust') ||
        value.contains('roth') ||
        value.contains('referral')) {
      return RiderPalette.purple;
    }
    return switch (category) {
      'jobs' => RiderPalette.blue,
      'deliveries' => RiderPalette.blue,
      'messages' => RiderPalette.blue,
      'schedule' => RiderPalette.amber,
      'earnings' => RiderPalette.green,
      'account' => RiderPalette.amber,
      _ => RiderPalette.blue,
    };
  }

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

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(icon),
        color: color,
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RiderGlassSurface(
        radius: 22,
        blur: 10,
        opacity: .56,
        edgeColor: accent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: .22)),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(height: 13),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: RiderPalette.paper,
                fontFamily: RiderTypography.heading,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: RiderPalette.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
