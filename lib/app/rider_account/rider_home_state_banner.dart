import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../home/bloc/home_bloc.dart';
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
        final rider = snapshot.data?.data() ?? const <String, dynamic>{};
        final state = RiderAccountStateResolver.resolve(rider);
        final online =
            '${rider['status'] ?? rider['driverStatus'] ?? ''}'.toLowerCase() ==
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xED0C121C),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x335EA0FF)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state == RiderAccountState.approved
                                ? (online
                                    ? 'Online and ready'
                                    : 'Ready when you are')
                                : 'Rider account update',
                            style: const TextStyle(
                              color: Colors.white,
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
                                color: Color(0xFFC9D2D7), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (state == RiderAccountState.approved)
                      TextButton(
                        onPressed: () => context.read<HomeBloc>().add(
                              SetRideStatus(
                                status: online
                                    ? RideStatus.offline
                                    : RideStatus.online,
                              ),
                            ),
                        child: Text(online ? 'Go offline' : 'Go online'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
