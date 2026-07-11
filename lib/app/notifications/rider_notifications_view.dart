import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../rider_design/rider_ui.dart';

class RiderNotificationsView extends StatelessWidget {
  const RiderNotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: RiderPalette.background,
      appBar: AppBar(
        backgroundColor: RiderPalette.background,
        foregroundColor: RiderPalette.paper,
        elevation: 0,
        title: const Text('Notifications'),
      ),
      body: uid == null
          ? const _NotificationEmpty()
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('recipientId', isEqualTo: uid)
                  .limit(40)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _NotificationEmpty(
                      message: 'Notifications are unavailable.');
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!.docs.toList()
                  ..sort((a, b) => _date(b.data()).compareTo(_date(a.data())));
                if (items.isEmpty) return const _NotificationEmpty();
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = items[index];
                    final data = doc.data();
                    final unread =
                        data['read'] != true && data['isRead'] != true;
                    return RiderGlassCard(
                      padding: const EdgeInsets.all(16),
                      onTap: unread
                          ? () => doc.reference
                              .update({'read': true, 'isRead': true})
                          : null,
                      child: Row(children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: RiderPalette.blue.withOpacity(.14),
                          ),
                          child: const Icon(Icons.notifications_none_rounded,
                              color: RiderPalette.blue),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${data['title'] ?? 'Circum update'}',
                                  style: const TextStyle(
                                      color: RiderPalette.paper,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('${data['body'] ?? data['message'] ?? ''}',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: RiderPalette.muted, height: 1.35)),
                            ],
                          ),
                        ),
                        if (unread)
                          const Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: CircleAvatar(
                                radius: 4, backgroundColor: RiderPalette.blue),
                          ),
                      ]),
                    );
                  },
                );
              },
            ),
    );
  }

  static DateTime _date(Map<String, dynamic> data) {
    final value = data['createdAt'] ?? data['timestamp'];
    return value is Timestamp
        ? value.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _NotificationEmpty extends StatelessWidget {
  const _NotificationEmpty({this.message = 'No notifications yet.'});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.notifications_none_rounded,
              color: RiderPalette.muted, size: 44),
          const SizedBox(height: 14),
          Text(message, style: const TextStyle(color: RiderPalette.muted)),
        ]),
      );
}
