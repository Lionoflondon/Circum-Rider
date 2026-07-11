import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../authentication/bloc/auth_bloc.dart';
import '../home/bloc/home_bloc.dart';
import '../notifications/rider_notifications_view.dart';
import '../rider_design/rider_ui.dart';
import '../rider_truth/rider_truth.dart';

class RiderDashboardView extends StatefulWidget {
  const RiderDashboardView({super.key, required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  @override
  State<RiderDashboardView> createState() => _RiderDashboardViewState();
}

class _RiderDashboardViewState extends State<RiderDashboardView> {
  @override
  void initState() {
    super.initState();
    context.read<HomeBloc>()
      ..add(CheckForPushToken())
      ..add(CheckForActiveRequest());
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const RiderEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Sign in required',
        message: 'Sign in to open your Rider dashboard.',
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('riderProfiles')
          .doc(uid)
          .snapshots(),
      builder: (context, profileSnapshot) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('riders')
              .doc(uid)
              .snapshots(),
          builder: (context, riderSnapshot) {
            final profile = <String, dynamic>{
              ...?riderSnapshot.data?.data(),
              ...?profileSnapshot.data?.data(),
            };
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('riderEarnings')
                  .doc(uid)
                  .snapshots(),
              builder: (context, earningsSnapshot) {
                final earnings = earningsSnapshot.data?.data() ?? const {};
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('deliveryRequests')
                      .where('assignedRider', isEqualTo: uid)
                      .limit(20)
                      .snapshots(),
                  builder: (context, deliverySnapshot) {
                    final deliveries = deliverySnapshot.data?.docs
                            .map((doc) => {'id': doc.id, ...doc.data()})
                            .toList() ??
                        const <Map<String, dynamic>>[];
                    final scheduled = deliveries
                        .where(
                            (item) => _isScheduled(item) && !_isFinished(item))
                        .toList();
                    final recent = deliveries.where(_isFinished).toList()
                      ..sort((a, b) => _millis(b).compareTo(_millis(a)));
                    return BlocBuilder<HomeBloc, HomeState>(
                      builder: (context, home) => CustomScrollView(
                        key: const PageStorageKey('rider-dashboard'),
                        slivers: [
                          SliverSafeArea(
                            bottom: false,
                            sliver: SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 14, 18, 28),
                              sliver: SliverList.list(children: [
                                _Header(
                                  profile: profile,
                                  onNotifications: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const RiderNotificationsView(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _AvailabilityCard(
                                  state: home,
                                  onToggle: () => context.read<HomeBloc>().add(
                                        SetRideStatus(
                                          status: home.rideStatus ==
                                                  RideStatus.offline
                                              ? RideStatus.online
                                              : RideStatus.offline,
                                        ),
                                      ),
                                ),
                                const SizedBox(height: 14),
                                _RankCard(profile: profile),
                                const SizedBox(height: 14),
                                _TodayGrid(earnings: earnings),
                                const SizedBox(height: 22),
                                RiderSectionTitle('Priority operations',
                                    action: 'View jobs',
                                    onAction: () => widget.onSelectTab(1)),
                                const SizedBox(height: 10),
                                _JobsSummary(
                                  home: home,
                                  onOpenJobs: () => widget.onSelectTab(1),
                                ),
                                const SizedBox(height: 22),
                                RiderSectionTitle('Upcoming schedule',
                                    action: 'View all',
                                    onAction: () => widget.onSelectTab(2)),
                                const SizedBox(height: 10),
                                _ScheduledSummary(
                                  job: scheduled.isEmpty
                                      ? null
                                      : scheduled.first,
                                  onTap: () => widget.onSelectTab(2),
                                ),
                                const SizedBox(height: 22),
                                const RiderSectionTitle('Recent activity'),
                                const SizedBox(height: 10),
                                _RecentSummary(items: recent.take(3).toList()),
                                const SizedBox(height: 22),
                                _QuickActions(onSelectTab: widget.onSelectTab),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  static bool _isScheduled(Map<String, dynamic> item) =>
      item['scheduled'] == true ||
      item['isScheduled'] == true ||
      item['scheduledAt'] != null;

  static bool _isFinished(Map<String, dynamic> item) => {
        'completed',
        'delivered',
        'cancelled',
        'failed',
      }.contains(
          '${item['deliveryState'] ?? item['status'] ?? ''}'.toLowerCase());

  static int _millis(Map<String, dynamic> item) {
    final value = item['completedAt'] ?? item['updatedAt'] ?? item['createdAt'];
    return value is Timestamp ? value.millisecondsSinceEpoch : 0;
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.profile});
  final Map<String, dynamic> profile;
  @override
  Widget build(BuildContext context) {
    final rank = RiderRankSnapshot.from(profile);
    if (rank == null) {
      return const RiderEmptyState(
          icon: Icons.sync_problem_rounded,
          title: 'Rank unavailable',
          message: 'Rider rank and trust data are still synchronising.');
    }
    return RiderGlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RiderRankProgress(rank: rank.rank, trustPoints: rank.trustPoints),
      if (rank.overrideReason != null) ...[
        const SizedBox(height: 8),
        Text(rank.overrideReason!,
            style: const TextStyle(color: RiderPalette.amber, fontSize: 11))
      ],
    ]));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.onNotifications});
  final Map<String, dynamic> profile;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final name = '${profile['firstName'] ?? auth.username ?? 'Rider'}'.trim();
    final firstName = name.split(' ').first;
    final photo =
        '${profile['profilePhoto'] ?? auth.profilePhoto ?? ''}'.trim();
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('CIRCUM RIDER',
              style: TextStyle(
                  color: RiderPalette.blue,
                  fontFamily: RiderTypography.mono,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4)),
          const SizedBox(height: 4),
          Text('Good ${_period()}, $firstName',
              style: const TextStyle(
                  color: RiderPalette.paper,
                  fontFamily: RiderTypography.heading,
                  fontSize: 28)),
        ]),
      ),
      IconButton(
        tooltip: 'Notifications',
        onPressed: onNotifications,
        icon: const Icon(Icons.notifications_none_rounded),
        color: RiderPalette.paper,
      ),
      const SizedBox(width: 4),
      CircleAvatar(
        radius: 21,
        backgroundColor: RiderPalette.panel,
        backgroundImage:
            photo.isEmpty ? null : CachedNetworkImageProvider(photo),
        child: photo.isEmpty
            ? Text(firstName.isEmpty ? 'R' : firstName[0].toUpperCase(),
                style: const TextStyle(
                    color: RiderPalette.paper, fontWeight: FontWeight.w800))
            : null,
      ),
    ]);
  }

  static String _period() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 18) return 'afternoon';
    return 'evening';
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.state, required this.onToggle});
  final HomeState state;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final online = state.rideStatus != RideStatus.offline;
    return RiderGlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? RiderPalette.green : RiderPalette.red,
              boxShadow: online
                  ? const [BoxShadow(color: RiderPalette.green, blurRadius: 9)]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Text(online ? 'Online and available' : 'You are currently offline',
              style: const TextStyle(
                  color: RiderPalette.paper,
                  fontFamily: RiderTypography.body,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        Text(
          online
              ? 'Circum is checking eligible delivery opportunities near you.'
              : 'Go online when you are ready to receive eligible jobs.',
          style: const TextStyle(
              color: RiderPalette.muted,
              fontFamily: RiderTypography.body,
              height: 1.35),
        ),
        if (state.message != null) ...[
          const SizedBox(height: 8),
          Text(state.message!,
              style: const TextStyle(color: RiderPalette.amber, fontSize: 12)),
        ],
        const SizedBox(height: 16),
        RiderPrimaryButton(
          label: online ? 'Go Offline' : 'Go Online',
          icon: online ? Icons.pause_rounded : Icons.power_settings_new_rounded,
          color: online ? RiderPalette.panel : RiderPalette.green,
          onPressed: state.canGoOnline || online ? onToggle : null,
        ),
      ]),
    );
  }
}

class _TodayGrid extends StatelessWidget {
  const _TodayGrid({required this.earnings});
  final Map<String, dynamic> earnings;

  @override
  Widget build(BuildContext context) {
    final today = _num(earnings['todayEarnings'] ?? earnings['availableToday']);
    final jobs = _num(earnings['todayCompletedJobs']).toInt();
    final pending =
        _num(earnings['pendingEarnings'] ?? earnings['pendingBalance']);
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      childAspectRatio: 1.18,
      children: [
        RiderMetric(value: '£${today.toStringAsFixed(2)}', label: 'TODAY'),
        RiderMetric(value: '$jobs', label: 'JOBS'),
        RiderMetric(value: '£${pending.toStringAsFixed(2)}', label: 'PENDING'),
      ],
    );
  }

  static double _num(Object? value) => value is num ? value.toDouble() : 0;
}

class _JobsSummary extends StatelessWidget {
  const _JobsSummary({required this.home, required this.onOpenJobs});
  final HomeState home;
  final VoidCallback onOpenJobs;

  @override
  Widget build(BuildContext context) {
    if (home.rideStatus == RideStatus.offline) {
      return RiderGlassCard(
          onTap: onOpenJobs,
          child: const Row(children: [
            Icon(Icons.fact_check_outlined, color: RiderPalette.blue),
            SizedBox(width: 12),
            Expanded(
                child: Text('No priority operational action right now.',
                    style: TextStyle(color: RiderPalette.muted))),
            Icon(Icons.chevron_right_rounded, color: RiderPalette.muted)
          ]));
    }
    if (home.requestStatus == RequestStatus.loading) {
      return const RiderGlassCard(
          child: Center(child: CircularProgressIndicator()));
    }
    final count = home.dispatchRequests.length;
    return RiderGlassCard(
      onTap: onOpenJobs,
      child: Row(children: [
        const Icon(Icons.route_rounded, color: RiderPalette.blue, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                count == 0
                    ? 'Looking for jobs'
                    : '$count eligible ${count == 1 ? 'job' : 'jobs'}',
                style: const TextStyle(
                    color: RiderPalette.paper, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Open the marketplace to review delivery details.',
                style: TextStyle(color: RiderPalette.muted, fontSize: 12)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: RiderPalette.muted),
      ]),
    );
  }
}

class _ScheduledSummary extends StatelessWidget {
  const _ScheduledSummary({required this.job, required this.onTap});
  final Map<String, dynamic>? job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (job == null) {
      return RiderEmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'No scheduled deliveries',
        message: 'Reserved jobs will appear here with their collection window.',
        actionLabel: 'Open schedule',
        onAction: onTap,
      );
    }
    return RiderGlassCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const RiderStatusBadge('SCHEDULED', color: RiderPalette.purple),
        const SizedBox(height: 12),
        Text(
            '${job!['pickupArea'] ?? job!['pickupPostcode'] ?? 'Pickup'} → ${job!['dropoffArea'] ?? job!['dropoffPostcode'] ?? 'Drop-off'}',
            style: const TextStyle(
                color: RiderPalette.paper, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
            '${job!['pickupWindow'] ?? job!['scheduledTime'] ?? 'Collection time pending'}',
            style: const TextStyle(color: RiderPalette.muted, fontSize: 12)),
      ]),
    );
  }
}

class _RecentSummary extends StatelessWidget {
  const _RecentSummary({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const RiderEmptyState(
        icon: Icons.history_rounded,
        title: 'No completed deliveries yet',
        message: 'Your most recent completed work will appear here.',
      );
    }
    return RiderGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: items
            .map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x1734D399),
                    child: Icon(Icons.check_rounded, color: RiderPalette.green),
                  ),
                  title: Text(
                      '${item['serviceType'] ?? item['deliveryType'] ?? 'Delivery'}',
                      style: const TextStyle(
                          color: RiderPalette.paper,
                          fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${item['dropoffArea'] ?? item['dropoffPostcode'] ?? 'Completed'}',
                      style: const TextStyle(color: RiderPalette.muted)),
                  trailing: Text(
                      _money(item['riderEarning'] ?? item['riderPay']),
                      style: const TextStyle(
                          color: RiderPalette.paper,
                          fontFamily: RiderTypography.mono)),
                ))
            .toList(),
      ),
    );
  }

  static String _money(Object? value) =>
      value is num ? '£${value.toStringAsFixed(2)}' : '—';
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onSelectTab});
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: _QuickAction(
                icon: Icons.work_outline_rounded,
                label: 'Jobs',
                onTap: () => onSelectTab(1))),
        const SizedBox(width: 8),
        Expanded(
            child: _QuickAction(
                icon: Icons.calendar_month_outlined,
                label: 'Schedule',
                onTap: () => onSelectTab(2))),
        const SizedBox(width: 8),
        Expanded(
            child: _QuickAction(
                icon: Icons.payments_outlined,
                label: 'Earnings',
                onTap: () => onSelectTab(3))),
      ]);
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: RiderPalette.panel,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(.08)),
          ),
          child: Column(children: [
            Icon(icon, color: RiderPalette.blue),
            const SizedBox(height: 7),
            Text(label,
                style: const TextStyle(
                    color: RiderPalette.paper,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}
