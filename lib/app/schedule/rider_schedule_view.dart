import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../rider_design/rider_ui.dart';

class RiderScheduleView extends StatelessWidget {
  const RiderScheduleView({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final content = uid == null
        ? const _ScheduleEmpty(message: 'Sign in to view your schedule.')
        : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('deliveryRequests')
                .where('assignedRider', isEqualTo: uid)
                .limit(30)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const _ScheduleEmpty(
                    message: 'Schedule is unavailable. Try again shortly.');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final jobs = snapshot.data!.docs.where((doc) {
                final data = doc.data();
                final state = '${data['status'] ?? data['deliveryState'] ?? ''}'
                    .toLowerCase();
                final scheduled = data['scheduled'] == true ||
                    data['isScheduled'] == true ||
                    data['scheduledAt'] != null;
                return scheduled &&
                    !{'completed', 'cancelled', 'expired', 'rejected'}
                        .contains(state);
              }).toList()
                ..sort((a, b) => _scheduledDate(a.data())
                    .compareTo(_scheduledDate(b.data())));
              if (jobs.isEmpty) {
                return const _ScheduleEmpty(
                    message:
                        'Reserved scheduled jobs will appear here with their collection window.');
              }
              return ListView.separated(
                padding: EdgeInsets.fromLTRB(18, embedded ? 18 : 8, 18, 28),
                itemCount: jobs.length + (embedded ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (embedded && index == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Schedule',
                          style: TextStyle(
                              color: RiderPalette.paper,
                              fontFamily: RiderTypography.heading,
                              fontSize: 30)),
                    );
                  }
                  return _ScheduledJobCard(
                    data: jobs[embedded ? index - 1 : index].data(),
                  );
                },
              );
            },
          );
    if (embedded) return SafeArea(bottom: false, child: content);
    return Scaffold(
      backgroundColor: RiderPalette.background,
      appBar: AppBar(
        backgroundColor: RiderPalette.background,
        foregroundColor: RiderPalette.paper,
        elevation: 0,
        title: const Text('Schedule'),
      ),
      body: content,
    );
  }

  static String area(dynamic value) {
    if (value is Map) {
      return '${value['area'] ?? value['city'] ?? value['postcode'] ?? 'Location pending'}';
    }
    final text = '$value'.trim();
    return text.isEmpty || text == 'null' ? 'Location pending' : text;
  }

  static String scheduledLabel(Map<String, dynamic> data) {
    final value = data['scheduledAt'] ??
        data['scheduledTime'] ??
        data['pickupWindow'] ??
        'Time pending';
    if (value is Timestamp) {
      final date = value.toDate().toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '$value';
  }

  static DateTime _scheduledDate(Map<String, dynamic> data) {
    final value = data['scheduledAt'] ?? data['scheduledTime'];
    return value is Timestamp
        ? value.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _ScheduledJobCard extends StatelessWidget {
  const _ScheduledJobCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final earning = data['riderEarning'] ?? data['riderPay'];
    final service =
        '${data['serviceType'] ?? data['deliveryType'] ?? _type(data)}';
    final scheduled = RiderScheduleView._scheduledDate(data);
    final readiness = scheduled.millisecondsSinceEpoch == 0
        ? 'Time pending'
        : scheduled.isBefore(DateTime.now())
            ? 'Ready to start'
            : _countdown(scheduled);
    return RiderGlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const RiderStatusBadge('SCHEDULED', color: RiderPalette.purple),
          const Spacer(),
          Text(earning is num ? '£${earning.toStringAsFixed(2)}' : '—',
              style: const TextStyle(
                  color: RiderPalette.paper,
                  fontFamily: RiderTypography.mono,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 14),
        Text(RiderScheduleView.area(data['pickupDetails'] ?? data['pickup']),
            style: const TextStyle(
                color: RiderPalette.paper,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Icon(Icons.arrow_downward_rounded,
              color: RiderPalette.muted, size: 17),
        ),
        Text(RiderScheduleView.area(data['dropoffDetails'] ?? data['dropoff']),
            style: const TextStyle(
                color: RiderPalette.paper,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          RiderStatusBadge(service.toUpperCase()),
          RiderStatusBadge(readiness.toUpperCase(),
              color: readiness == 'Ready to start'
                  ? RiderPalette.green
                  : RiderPalette.amber),
        ]),
        const SizedBox(height: 12),
        Text(RiderScheduleView.scheduledLabel(data),
            style: const TextStyle(
                color: RiderPalette.muted,
                fontFamily: RiderTypography.mono,
                fontSize: 12)),
      ]),
    );
  }

  static String _type(Map<String, dynamic> data) {
    if (data['isHealthPlus'] == true) return 'Health+';
    if (data['isGift'] == true) return 'Gift';
    if (data['isBusiness'] == true) return 'Business';
    if (data['requiresVanguard'] == true) return 'Vanguard';
    if (data['isHeavyDuty'] == true) return 'Heavy Duty';
    return 'Standard';
  }

  static String _countdown(DateTime date) {
    final difference = date.difference(DateTime.now());
    if (difference.inDays > 0) return 'Starts in ${difference.inDays}d';
    if (difference.inHours > 0) return 'Starts in ${difference.inHours}h';
    return 'Starts in ${difference.inMinutes.clamp(1, 59)}m';
  }
}

class _ScheduleEmpty extends StatelessWidget {
  const _ScheduleEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            const Text('Schedule',
                style: TextStyle(
                    color: RiderPalette.paper,
                    fontFamily: RiderTypography.heading,
                    fontSize: 30)),
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
