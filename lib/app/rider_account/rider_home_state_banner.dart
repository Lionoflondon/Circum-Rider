import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../rider_design/rider_ui.dart';
import 'rider_account_state.dart';

/// A read-only summary over the existing profile documents. It deliberately
/// does not create jobs, balances, trust values, or vehicle defaults.
class RiderHomeStateBanner extends StatelessWidget {
  const RiderHomeStateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('riders').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final baseRider = snapshot.data?.data() ?? const <String, dynamic>{};
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('riderProfiles')
              .doc(uid)
              .snapshots(),
          builder: (context, profileSnapshot) {
            final profile =
                profileSnapshot.data?.data() ?? const <String, dynamic>{};
            final rider = <String, dynamic>{...baseRider, ...profile};
            final state = RiderAccountStateResolver.resolve(rider);
            final online = '${rider['status'] ?? rider['driverStatus'] ?? ''}'
                    .toLowerCase() ==
                'online';
            final vehicle = rider['vehicle'] is Map
                ? Map<String, dynamic>.from(rider['vehicle'] as Map)
                : const <String, dynamic>{};
            final vehicleSummary =
                '${rider['vehicleType'] ?? vehicle['type'] ?? ''}'.trim();
            final rank = '${rider['riderRank'] ?? rider['rank'] ?? ''}'.trim();
            final trust = rider['trustPoints'];
            final earnings = rider['todayEarnings'];
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: RiderGlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state == RiderAccountState.approved
                                    ? (online
                                        ? 'You are online'
                                        : 'Ready when you are, ${_firstName(rider)}')
                                    : 'Rider account update',
                                style: const TextStyle(
                                  color: RiderPalette.paper,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _summary(
                                  state: state,
                                  online: online,
                                  vehicle: vehicleSummary,
                                  rank: rank,
                                  trust: trust,
                                  earnings: earnings,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: RiderPalette.muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (state == RiderAccountState.approved)
                          RiderStatusBadge(online ? 'ONLINE' : 'OFFLINE',
                              color: online
                                  ? RiderPalette.green
                                  : RiderPalette.muted),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _firstName(Map<String, dynamic> rider) {
    final value = '${rider['firstName'] ?? rider['name'] ?? 'Rider'}'.trim();
    return value.split(' ').first;
  }

  String _summary({
    required RiderAccountState state,
    required bool online,
    required String vehicle,
    required String rank,
    required Object? trust,
    required Object? earnings,
  }) {
    if (state != RiderAccountState.approved) {
      return switch (state) {
        RiderAccountState.pendingReview ||
        RiderAccountState.submitted =>
          'Your application is under review.',
        RiderAccountState.moreInformationRequired =>
          'More information is needed to continue your review.',
        RiderAccountState.suspended ||
        RiderAccountState.frozen =>
          'Operational actions are disabled.',
        _ => 'Complete your Rider account to start delivering.',
      };
    }
    final details = <String>[
      if (vehicle.isNotEmpty) vehicle,
      if (rank.isNotEmpty) rank,
      if (trust is num) '${trust.toStringAsFixed(0)} trust points',
      if (earnings is num) 'Today: £${earnings.toStringAsFixed(2)}',
    ];
    return details.isEmpty
        ? (online
            ? 'Searching for available work.'
            : 'Go online when you are ready.')
        : details.join(' · ');
  }
}
