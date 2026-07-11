import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../rider_design/rider_ui.dart';

class RiderScheduleView extends StatelessWidget {
  const RiderScheduleView({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: RiderPalette.background,
      appBar: AppBar(
        backgroundColor: RiderPalette.background,
        foregroundColor: RiderPalette.paper,
        elevation: 0,
        title: const Text('Schedule'),
      ),
      body: uid == null
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
                  final state =
                      '${data['status'] ?? data['deliveryState'] ?? ''}'
                          .toLowerCase();
                  final scheduled = data['scheduled'] == true ||
                      data['isScheduled'] == true ||
                      data['scheduledAt'] != null;
                  return scheduled &&
                      !{'completed', 'cancelled', 'expired', 'rejected'}
                          .contains(state);
                }).toList();
                if (jobs.isEmpty) {
                  return const _ScheduleEmpty(
                      message: 'No scheduled deliveries yet.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = jobs[index].data();
                    return RiderGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const RiderStatusBadge('SCHEDULED',
                              color: RiderPalette.purple),
                          const SizedBox(height: 12),
                          Text(_area(data['pickupDetails'] ?? data['pickup']),
                              style: const TextStyle(
                                  color: RiderPalette.paper,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 7),
                            child: Icon(Icons.arrow_downward_rounded,
                                color: RiderPalette.muted, size: 17),
                          ),
                          Text(_area(data['dropoffDetails'] ?? data['dropoff']),
                              style: const TextStyle(
                                  color: RiderPalette.paper,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          Text(_scheduledLabel(data),
                              style:
                                  const TextStyle(color: RiderPalette.muted)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  static String _area(dynamic value) {
    if (value is Map) {
      return '${value['area'] ?? value['city'] ?? value['postcode'] ?? 'Location pending'}';
    }
    final text = '$value'.trim();
    return text.isEmpty || text == 'null' ? 'Location pending' : text;
  }

  static String _scheduledLabel(Map<String, dynamic> data) {
    final value = data['scheduledAt'] ??
        data['scheduledTime'] ??
        data['pickupWindow'] ??
        'Time pending';
    if (value is Timestamp) return value.toDate().toLocal().toString();
    return '$value';
  }
}

class _ScheduleEmpty extends StatelessWidget {
  const _ScheduleEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_month_outlined,
                color: RiderPalette.muted, size: 42),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: RiderPalette.muted)),
          ]),
        ),
      );
}
