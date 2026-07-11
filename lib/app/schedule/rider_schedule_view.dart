import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../rider_jobs/rider_job_offer_screen.dart';
import '../rider_jobs/rider_offer_card.dart';
import '../rider_design/rider_ui.dart';

enum _ScheduleFilter { all, today, week, vanguard }

class RiderScheduleView extends StatefulWidget {
  const RiderScheduleView({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<RiderScheduleView> createState() => _RiderScheduleViewState();
}

class _RiderScheduleViewState extends State<RiderScheduleView> {
  _ScheduleFilter _filter = _ScheduleFilter.all;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final content = uid == null
        ? const _ScheduleEmpty(message: 'Sign in to view your schedule.')
        : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('deliveryRequests')
                .where('assignedRider', isEqualTo: uid)
                .limit(40)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const _ScheduleEmpty(
                  message: 'Schedule is unavailable. Try again shortly.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final jobs = snapshot.data!.docs
                  .map((doc) => _ScheduleJob.from(doc.id, doc.data()))
                  .where((job) => job.isVisible)
                  .toList()
                ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
              final filtered = jobs.where(_matchesFilter).toList();

              return CustomScrollView(
                slivers: [
                  SliverSafeArea(
                    bottom: false,
                    sliver: SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        widget.embedded ? 18 : 8,
                        20,
                        28,
                      ),
                      sliver: SliverList.list(
                        children: [
                          const _ScheduleHeader(),
                          const SizedBox(height: 14),
                          _FilterRow(
                            selected: _filter,
                            onChanged: (value) => setState(() {
                              _filter = value;
                            }),
                          ),
                          const SizedBox(height: 20),
                          if (filtered.isEmpty)
                            const _ScheduleEmptyPanel()
                          else
                            ..._grouped(filtered).entries.map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 22),
                                    child: _DayGroup(
                                      label: entry.key,
                                      jobs: entry.value,
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );

    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: RiderPalette.background,
      body: content,
    );
  }

  bool _matchesFilter(_ScheduleJob job) {
    final now = DateTime.now();
    final local = job.scheduledAt.toLocal();
    return switch (_filter) {
      _ScheduleFilter.all => true,
      _ScheduleFilter.today => local.year == now.year &&
          local.month == now.month &&
          local.day == now.day,
      _ScheduleFilter.week =>
        local.isBefore(now.add(const Duration(days: 7))) &&
            !local.isBefore(DateTime(now.year, now.month, now.day)),
      _ScheduleFilter.vanguard => job.service == _ScheduleService.vanguard,
    };
  }

  static Map<String, List<_ScheduleJob>> _grouped(List<_ScheduleJob> jobs) {
    final grouped = <String, List<_ScheduleJob>>{};
    for (final job in jobs) {
      grouped.putIfAbsent(job.dayLabel, () => []).add(job);
    }
    return grouped;
  }
}

class _ScheduleHeader extends StatelessWidget {
  const _ScheduleHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (Navigator.canPop(context)) ...[
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: .045),
              side: BorderSide(color: Colors.white.withValues(alpha: .09)),
            ),
            icon: const Icon(Icons.chevron_left_rounded,
                color: RiderPalette.paper),
          ),
          const SizedBox(width: 10),
        ],
        const Text(
          'Schedule',
          style: TextStyle(
            color: RiderPalette.paper,
            fontFamily: RiderTypography.heading,
            fontSize: 30,
          ),
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onChanged});

  final _ScheduleFilter selected;
  final ValueChanged<_ScheduleFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            active: selected == _ScheduleFilter.all,
            onTap: () => onChanged(_ScheduleFilter.all),
          ),
          _FilterChip(
            label: 'Today',
            active: selected == _ScheduleFilter.today,
            onTap: () => onChanged(_ScheduleFilter.today),
          ),
          _FilterChip(
            label: 'This week',
            active: selected == _ScheduleFilter.week,
            onTap: () => onChanged(_ScheduleFilter.week),
          ),
          _FilterChip(
            label: 'Vanguard',
            active: selected == _ScheduleFilter.vanguard,
            onTap: () => onChanged(_ScheduleFilter.vanguard),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => onTap(),
        backgroundColor: Colors.white.withValues(alpha: .045),
        selectedColor: RiderPalette.blue,
        side: BorderSide(
          color:
              active ? Colors.transparent : Colors.white.withValues(alpha: .09),
        ),
        labelStyle: TextStyle(
          color: active ? Colors.white : RiderPalette.muted,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
        shape: const StadiumBorder(),
      ),
    );
  }
}

class _DayGroup extends StatelessWidget {
  const _DayGroup({required this.label, required this.jobs});

  final String label;
  final List<_ScheduleJob> jobs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF5F6779),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: .9,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${jobs.length}',
                style: const TextStyle(
                  color: RiderPalette.muted,
                  fontFamily: RiderTypography.mono,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final job in jobs) ...[
          _ScheduledJobCard(job: job),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ScheduledJobCard extends StatelessWidget {
  const _ScheduledJobCard({required this.job});

  final _ScheduleJob job;

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      onTap: () => _showDetails(context, job),
      padding: const EdgeInsets.all(18),
      radius: 22,
      blur: 8,
      opacity: .76,
      borderColor: job.ready
          ? RiderPalette.green.withValues(alpha: .30)
          : Colors.white.withValues(alpha: .09),
      edgeColor: job.service.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ServiceIcon(service: job.service),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  job.service.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RiderPalette.paper,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .3,
                  ),
                ),
              ),
              Text(
                job.earningLabel,
                style: const TextStyle(
                  color: RiderPalette.paper,
                  fontFamily: RiderTypography.mono,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const _RouteDot(color: RiderPalette.blue),
                  Container(
                    width: 2,
                    height: 28,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const _RouteDot(color: RiderPalette.purple),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.pickup,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RiderPalette.paper,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      job.dropoff,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RiderPalette.paper,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                job.readinessLabel.toUpperCase(),
                style: TextStyle(
                  color: job.readinessColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .3,
                ),
              ),
              const Spacer(),
              Text(
                job.timeLabel,
                style: const TextStyle(
                  color: RiderPalette.muted,
                  fontFamily: RiderTypography.mono,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, _ScheduleJob job) {
    if (job.ready) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RiderAcceptedJobScreen(
              offer: RiderJobOffer.fromFirestore(
                docId: job.id,
                data: job.raw,
              ),
              riderId: uid,
              riderRank: 'Agent',
            ),
          ),
        );
        return;
      }
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RiderPalette.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.service.label,
                style: const TextStyle(
                  color: RiderPalette.paper,
                  fontFamily: RiderTypography.heading,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${job.pickup} → ${job.dropoff}',
                style: const TextStyle(color: RiderPalette.muted),
              ),
              const SizedBox(height: 16),
              Text(
                job.ready
                    ? 'This scheduled delivery is ready to start through the existing active-delivery flow.'
                    : 'This scheduled delivery remains reserved until its operational window.',
                style: const TextStyle(color: RiderPalette.paper, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon({required this.service});

  final _ScheduleService service;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: service.color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(service.icon, color: service.color, size: 18),
    );
  }
}

class _RouteDot extends StatelessWidget {
  const _RouteDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .18),
            spreadRadius: 3,
            blurRadius: 0,
          ),
        ],
      ),
    );
  }
}

class _ScheduleEmptyPanel extends StatelessWidget {
  const _ScheduleEmptyPanel();

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
      radius: 22,
      blur: 8,
      opacity: .74,
      edgeColor: RiderPalette.purple,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: RiderPalette.purple.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: RiderPalette.purple.withValues(alpha: .25),
              ),
            ),
            child: const Icon(Icons.calendar_month_outlined,
                color: RiderPalette.purple),
          ),
          const SizedBox(height: 12),
          const Text(
            'No scheduled deliveries',
            style: TextStyle(
              color: RiderPalette.paper,
              fontFamily: RiderTypography.heading,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Reserved scheduled jobs will appear here with their collection window.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RiderPalette.muted,
              height: 1.5,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleEmpty extends StatelessWidget {
  const _ScheduleEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const _ScheduleHeader(),
            const SizedBox(height: 18),
            RiderEmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'No scheduled deliveries',
              message: message,
            ),
          ],
        ),
      );
}

class _ScheduleJob {
  const _ScheduleJob({
    required this.id,
    required this.raw,
    required this.service,
    required this.pickup,
    required this.dropoff,
    required this.scheduledAt,
    required this.status,
  });

  final String id;
  final Map<String, dynamic> raw;
  final _ScheduleService service;
  final String pickup;
  final String dropoff;
  final DateTime scheduledAt;
  final String status;

  bool get isVisible {
    final hidden = {'completed', 'cancelled', 'expired', 'rejected'};
    final scheduled = raw['scheduled'] == true ||
        raw['isScheduled'] == true ||
        raw['scheduledAt'] != null;
    return scheduled && !hidden.contains(status);
  }

  bool get ready {
    final readiness =
        '${raw['scheduleReadiness'] ?? raw['operationalWindowStatus'] ?? raw['readyState'] ?? ''}'
            .trim()
            .toLowerCase();
    return raw['readyToStart'] == true ||
        raw['canStart'] == true ||
        readiness == 'ready' ||
        readiness == 'ready_to_start' ||
        status == 'ready_to_start';
  }

  String get earningLabel {
    final earning = raw['riderEarning'] ?? raw['riderPay'];
    return earning is num ? '£${earning.toStringAsFixed(2)}' : '—';
  }

  String get readinessLabel {
    if (ready) return 'Ready to start';
    final difference = scheduledAt.difference(DateTime.now());
    if (difference.inDays > 0) return 'Starts in ${difference.inDays}d';
    if (difference.inHours > 0) return 'Starts in ${difference.inHours}h';
    return 'Starts in ${difference.inMinutes.clamp(1, 59)}m';
  }

  Color get readinessColor => ready ? RiderPalette.green : RiderPalette.amber;

  String get timeLabel {
    final local = scheduledAt.toLocal();
    return '${_two(local.day)}/${_two(local.month)}/${local.year} · ${_two(local.hour)}:${_two(local.minute)}';
  }

  String get dayLabel {
    final now = DateTime.now();
    final local = scheduledAt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    if (date == today) return 'Today';
    if (date == today.add(const Duration(days: 1))) return 'Tomorrow';
    return '${_weekday(local.weekday)} ${local.day} ${_month(local.month)}';
  }

  static _ScheduleJob from(String id, Map<String, dynamic> data) {
    return _ScheduleJob(
      id: id,
      raw: data,
      service: _ScheduleService.from(data),
      pickup: area(data['pickupDetails'] ??
          data['pickup'] ??
          data['pickupArea'] ??
          data['pickupPostcode']),
      dropoff: area(data['dropoffDetails'] ??
          data['dropoff'] ??
          data['dropoffArea'] ??
          data['dropoffPostcode']),
      scheduledAt: scheduledDate(data),
      status: '${data['status'] ?? data['deliveryState'] ?? ''}'.toLowerCase(),
    );
  }

  static String area(dynamic value) {
    if (value is Map) {
      return '${value['area'] ?? value['city'] ?? value['postcode'] ?? 'Location pending'}';
    }
    final text = '$value'.trim();
    return text.isEmpty || text == 'null' ? 'Location pending' : text;
  }

  static DateTime scheduledDate(Map<String, dynamic> data) {
    final value = data['scheduledAt'] ?? data['scheduledTime'];
    return value is Timestamp ? value.toDate() : DateTime.now();
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
  static String _weekday(int value) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][value - 1];
  static String _month(int value) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][value - 1];
}

enum _ScheduleService {
  standard('Standard', Icons.work_outline_rounded, RiderPalette.blue),
  vanguard('Vanguard', Icons.shield_outlined, RiderPalette.purple),
  gift('Gifts by CIRCUM', Icons.card_giftcard_rounded, Color(0xFFF9A8D4)),
  health('Health+', Icons.health_and_safety_outlined, RiderPalette.green),
  business('Business', Icons.business_center_outlined, RiderPalette.amber);

  const _ScheduleService(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static _ScheduleService from(Map<String, dynamic> data) {
    final text = '${data['serviceType'] ?? data['deliveryType'] ?? ''}'
        .trim()
        .toLowerCase();
    if (data['requiresVanguard'] == true || text.contains('vanguard')) {
      return _ScheduleService.vanguard;
    }
    if (data['isGift'] == true || text.contains('gift')) {
      return _ScheduleService.gift;
    }
    if (data['isHealthPlus'] == true || text.contains('health')) {
      return _ScheduleService.health;
    }
    if (data['isBusiness'] == true || text.contains('business')) {
      return _ScheduleService.business;
    }
    return _ScheduleService.standard;
  }
}
