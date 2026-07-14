import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../authentication/bloc/auth_bloc.dart';
import '../communication/rider_communication_service.dart';
import '../rider_internal_access/rider_internal_access.dart';
import '../home/bloc/home_bloc.dart';
import '../notifications/rider_notifications_view.dart';
import '../onboarding/rider_guide_view.dart';
import '../recognitions/rider_recognitions.dart';
import '../rider_account/rider_account_state.dart';
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
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('riderPresence')
                      .doc(uid)
                      .snapshots(),
                  builder: (context, presenceSnapshot) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('deliveryRequests')
                          .where('assignedRider', isEqualTo: uid)
                          .limit(24)
                          .snapshots(),
                      builder: (context, assignedSnapshot) {
                        return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('deliveryRequests')
                              .where('status', isEqualTo: 'requested')
                              .limit(8)
                              .snapshots(),
                          builder: (context, offersSnapshot) {
                            final assigned = _docs(assignedSnapshot);
                            final data = _DashboardData(
                              profile: profile,
                              earnings:
                                  earningsSnapshot.data?.data() ?? const {},
                              presence:
                                  presenceSnapshot.data?.data() ?? const {},
                              eligibleOffers: _docs(offersSnapshot),
                              scheduled: assigned
                                  .where((item) =>
                                      _isScheduled(item) && !_isFinished(item))
                                  .toList()
                                ..sort((a, b) => _time(a).compareTo(_time(b))),
                              recent: assigned.where(_isFinished).toList()
                                ..sort((a, b) => _time(b).compareTo(_time(a))),
                              loading: profileSnapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  riderSnapshot.connectionState ==
                                      ConnectionState.waiting,
                              hasDataError: profileSnapshot.hasError ||
                                  riderSnapshot.hasError ||
                                  earningsSnapshot.hasError ||
                                  presenceSnapshot.hasError ||
                                  assignedSnapshot.hasError ||
                                  offersSnapshot.hasError,
                              notificationsUnavailable: false,
                            );
                            return BlocBuilder<HomeBloc, HomeState>(
                              builder: (context, homeState) {
                                final online = data.isOnline;
                                final mergedHome = homeState.copyWith(
                                  rideStatus: online
                                      ? RideStatus.online
                                      : RideStatus.offline,
                                );
                                return _DashboardSurface(
                                  data: data,
                                  home: mergedHome,
                                  onSelectTab: widget.onSelectTab,
                                  onToggleAvailability: () =>
                                      context.read<HomeBloc>().add(
                                            SetRideStatus(
                                              status: online
                                                  ? RideStatus.offline
                                                  : RideStatus.online,
                                            ),
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
              },
            );
          },
        );
      },
    );
  }

  static List<Map<String, dynamic>> _docs(
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) =>
      snapshot.data?.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList() ??
      const <Map<String, dynamic>>[];

  static bool _isScheduled(Map<String, dynamic> item) =>
      item['scheduled'] == true ||
      item['isScheduled'] == true ||
      item['scheduledAt'] != null;

  static bool _isFinished(Map<String, dynamic> item) => {
        'completed',
        'delivered',
      }.contains(
          '${item['deliveryState'] ?? item['status'] ?? ''}'.toLowerCase());

  static int _time(Map<String, dynamic> item) {
    final value = item['scheduledAt'] ??
        item['collectionStart'] ??
        item['completedAt'] ??
        item['updatedAt'] ??
        item['createdAt'];
    return value is Timestamp ? value.millisecondsSinceEpoch : 0;
  }
}

class _DashboardData {
  const _DashboardData({
    required this.profile,
    required this.earnings,
    required this.presence,
    required this.eligibleOffers,
    required this.scheduled,
    required this.recent,
    required this.loading,
    required this.hasDataError,
    required this.notificationsUnavailable,
  });

  final Map<String, dynamic> profile;
  final Map<String, dynamic> earnings;
  final Map<String, dynamic> presence;
  final List<Map<String, dynamic>> eligibleOffers;
  final List<Map<String, dynamic>> scheduled;
  final List<Map<String, dynamic>> recent;
  final bool loading;
  final bool hasDataError;
  final bool notificationsUnavailable;

  bool get isOnline =>
      presence['isOnline'] == true &&
      '${presence['availabilityStatus'] ?? ''}'.toLowerCase() != 'offline';
}

class _DashboardSurface extends StatelessWidget {
  const _DashboardSurface({
    required this.data,
    required this.home,
    required this.onSelectTab,
    required this.onToggleAvailability,
  });

  final _DashboardData data;
  final HomeState home;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onToggleAvailability;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: RiderPalette.blue,
      backgroundColor: RiderPalette.panel,
      onRefresh: () async {
        context.read<HomeBloc>()
          ..add(CheckForPushToken())
          ..add(CheckForActiveRequest());
      },
      child: CustomScrollView(
        key: const PageStorageKey('rider-dashboard'),
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              sliver: SliverList.list(
                children: [
                  _DashboardHeader(
                    profile: data.profile,
                    onNotifications: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RiderNotificationsView(onNavigateTab: onSelectTab),
                      ),
                    ),
                    onProfile: () => onSelectTab(4),
                  ),
                  if (data.hasDataError) ...[
                    const SizedBox(height: 14),
                    const _InlineNotice(
                      icon: Icons.cloud_off_rounded,
                      title: 'Some dashboard data is unavailable',
                      message: 'Pull to refresh or try again shortly.',
                    ),
                  ],
                  const SizedBox(height: 18),
                  _AvailabilityCard(
                    home: home,
                    online: data.isOnline,
                    onToggle: onToggleAvailability,
                  ),
                  FutureBuilder<bool>(
                    future: RiderInternalAccess.enabled(),
                    builder: (context, snapshot) {
                      if (snapshot.data != true) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: _InternalDiagnosticsCard(
                          presence: data.presence,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _DashboardGuideEntry(profile: data.profile),
                  const SizedBox(height: 14),
                  _RankCard(profile: data.profile),
                  const SizedBox(height: 18),
                  _TodaySection(earnings: data.earnings),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'Available deliveries',
                    action: data.eligibleOffers.isEmpty ? null : 'View all',
                    onAction: () => onSelectTab(1),
                  ),
                  const SizedBox(height: 10),
                  _PriorityJobsCard(
                    online: data.isOnline,
                    offers: data.eligibleOffers,
                    onTap: () => onSelectTab(1),
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'Upcoming schedule',
                    action: 'View all',
                    onAction: () => onSelectTab(2),
                  ),
                  const SizedBox(height: 10),
                  _ScheduleCard(
                    job: data.scheduled.isEmpty ? null : data.scheduled.first,
                    onTap: () => onSelectTab(2),
                  ),
                  const SizedBox(height: 24),
                  const _SmallLabel('Recent activity'),
                  const SizedBox(height: 10),
                  _RecentActivityCard(
                    items: data.recent.take(2).toList(),
                    onTap: () => onSelectTab(3),
                  ),
                  const SizedBox(height: 24),
                  _QuickActions(onSelectTab: onSelectTab),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.profile,
    required this.onNotifications,
    required this.onProfile,
  });

  final Map<String, dynamic> profile;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final rawName =
        '${profile['firstName'] ?? profile['name'] ?? auth.username ?? ''}'
            .trim();
    final firstName = rawName.isEmpty ? 'Rider' : rawName.split(' ').first;
    final photo =
        '${profile['profilePhoto'] ?? profile['photoUrl'] ?? auth.profilePhoto ?? ''}'
            .trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CIRCUM RIDER',
                style: TextStyle(
                  color: RiderPalette.blue,
                  fontFamily: RiderTypography.mono,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Good ${_period()}, $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RiderPalette.paper,
                  fontFamily: RiderTypography.heading,
                  fontSize: 27,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
        _NotificationButton(onTap: onNotifications),
        const SizedBox(width: 10),
        Semantics(
          button: true,
          label: 'Open Rider profile',
          child: GestureDetector(
            onTap: onProfile,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: RiderPalette.blue,
              backgroundImage:
                  photo.isEmpty ? null : CachedNetworkImageProvider(photo),
              child: photo.isEmpty
                  ? Text(
                      _initials(rawName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  static String _period() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 18) return 'afternoon';
    return 'evening';
  }

  static String _initials(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'R';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: .045),
        side: BorderSide(color: Colors.white.withValues(alpha: .09)),
      ),
      icon: StreamBuilder<int?>(
        stream: RiderCommunicationService().watchUnreadNotificationCount(),
        builder: (context, snapshot) {
          final unread = snapshot.data ?? 0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded,
                  color: RiderPalette.paper, size: 20),
              if (snapshot.hasData && unread > 0)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Semantics(
                    label: '$unread unread notifications',
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: RiderPalette.purple,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: RiderPalette.background,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.home,
    required this.online,
    required this.onToggle,
  });

  final HomeState home;
  final bool online;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      opacity: .66,
      edgeColor: online ? RiderPalette.green : RiderPalette.red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: online ? RiderPalette.green : RiderPalette.red,
                  boxShadow: [
                    BoxShadow(
                      color: (online ? RiderPalette.green : RiderPalette.red)
                          .withValues(alpha: .34),
                      blurRadius: 12,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  online ? 'Online and available' : 'You are currently offline',
                  style: const TextStyle(
                    color: RiderPalette.paper,
                    fontWeight: FontWeight.w700,
                    fontFamily: RiderTypography.body,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            online
                ? 'Circum is checking eligible delivery opportunities near you.'
                : 'Go online when you are ready to receive eligible jobs.',
            style: const TextStyle(
              color: RiderPalette.muted,
              fontFamily: RiderTypography.body,
              fontSize: 12.5,
              height: 1.48,
            ),
          ),
          if (home.message != null) ...[
            const SizedBox(height: 10),
            Text(
              home.message!,
              style: const TextStyle(color: RiderPalette.amber, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 16),
          FutureBuilder<bool>(
            future: RiderInternalAccess.enabled(),
            builder: (context, internalAccess) {
              final allowed =
                  internalAccess.data == true || home.canGoOnline || online;
              return SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: allowed ? onToggle : null,
                  icon: Icon(
                    online
                        ? Icons.pause_rounded
                        : Icons.power_settings_new_rounded,
                    size: 18,
                  ),
                  label: Text(online ? 'Go offline' : 'Go online'),
                  style: FilledButton.styleFrom(
                    backgroundColor: online
                        ? Colors.white.withValues(alpha: .06)
                        : RiderPalette.green,
                    foregroundColor:
                        online ? RiderPalette.paper : RiderPalette.background,
                    disabledBackgroundColor:
                        Colors.white.withValues(alpha: .05),
                    disabledForegroundColor: RiderPalette.muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: online
                          ? BorderSide(
                              color: Colors.white.withValues(alpha: .16))
                          : BorderSide.none,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InternalDiagnosticsCard extends StatelessWidget {
  const _InternalDiagnosticsCard({required this.presence});

  final Map<String, dynamic> presence;

  @override
  Widget build(BuildContext context) {
    final location = presence['currentLocation'];
    final locationMap = location is Map ? location : const {};
    final rows = <({String label, String value})>[
      (
        label: 'GPS status',
        value: _clean(presence['gpsStatus'], fallback: 'Unknown')
      ),
      (
        label: 'Accuracy',
        value: _meters(locationMap['accuracyMeters'] ?? locationMap['accuracy'])
      ),
      (
        label: 'Last fix',
        value: _age(locationMap['updatedAt'] ?? presence['lastLocationAt'])
      ),
      (label: 'Update frequency', value: 'Idle heartbeat: 45s'),
      (
        label: 'Background tracking',
        value: _clean(presence['backgroundTracking'], fallback: 'Unknown')
      ),
      (
        label: 'Connectivity',
        value: _clean(presence['connectionStatus'], fallback: 'Unknown')
      ),
      (
        label: 'Battery optimisation',
        value: _clean(presence['batteryOptimisation'], fallback: 'Unknown')
      ),
      (label: 'Last backend upload', value: _age(presence['lastHeartbeatAt'])),
      (
        label: 'Dispatch eligibility',
        value: presence['dispatchEligible'] == true
            ? 'Eligible'
            : 'Waiting for healthy GPS'
      ),
    ];

    return RiderGlassSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.monitor_heart_rounded,
                  color: RiderPalette.blue, size: 18),
              SizedBox(width: 8),
              Text(
                'Internal dispatch diagnostics',
                style: TextStyle(
                  color: RiderPalette.paper,
                  fontFamily: RiderTypography.body,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.label,
                      style: const TextStyle(
                        color: RiderPalette.muted,
                        fontFamily: RiderTypography.body,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    row.value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: RiderPalette.paper,
                      fontFamily: RiderTypography.mono,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _clean(Object? value, {required String fallback}) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty) return fallback;
    return text
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'),
            (match) => '${match.group(1)} ${match.group(2)}')
        .toLowerCase()
        .replaceFirstMapped(
            RegExp(r'^[a-z]'), (match) => match.group(0)!.toUpperCase());
  }

  String _meters(Object? value) {
    final meters = value is num ? value.toDouble() : double.tryParse('$value');
    if (meters == null || meters <= 0) return 'Unknown';
    return '${meters.toStringAsFixed(0)} m';
  }

  String _age(Object? value) {
    final millis = _millis(value);
    if (millis == null) return 'Unknown';
    final elapsed =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(millis));
    if (elapsed.inSeconds < 15) return 'Just now';
    if (elapsed.inMinutes < 1) return '${elapsed.inSeconds}s ago';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
    return '${elapsed.inHours}h ago';
  }

  int? _millis(Object? value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }
}

class _DashboardGuideEntry extends StatelessWidget {
  const _DashboardGuideEntry({required this.profile});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final progress = RiderApprovalProgress.fromBackend(
      accountExists: user != null,
      firebaseEmailVerified: user?.emailVerified == true,
      rider: profile,
    );
    return RiderGuideEntryCard(
      progress: progress,
      compact: true,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RiderGuideView(
            authenticated: true,
            progress: progress,
          ),
        ),
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.profile});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final rank = RiderRankSnapshot.from(profile);
    if (rank == null) {
      return const RiderGlassSurface(
        padding: EdgeInsets.all(18),
        opacity: .62,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rank pending',
                style: TextStyle(
                    color: RiderPalette.paper, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('Build trust with every completed delivery.',
                style: TextStyle(color: RiderPalette.muted, fontSize: 12.5)),
          ],
        ),
      );
    }

    final progress = _RankProgressData.forTrust(rank.trustPoints);
    final note = progress.nextRank == null
        ? 'Highest Rider rank achieved'
        : '${progress.remaining} points to ${progress.nextRank}';
    final recognitions = RiderRecognitions.from(profile);

    return RiderGlassSurface(
      padding: const EdgeInsets.all(18),
      opacity: .64,
      edgeColor: RiderPalette.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                rank.rank.toUpperCase(),
                style: const TextStyle(
                  color: RiderPalette.green,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: .4,
                ),
              ),
              const Spacer(),
              Text(
                '${rank.trustPoints} TRUST',
                style: const TextStyle(
                  color: RiderPalette.paper,
                  fontFamily: RiderTypography.mono,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.progress,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: .07),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(RiderPalette.green),
            ),
          ),
          const SizedBox(height: 7),
          Text(note,
              style: const TextStyle(color: RiderPalette.muted, fontSize: 11)),
          if (rank.overrideReason != null) ...[
            const SizedBox(height: 7),
            Text(rank.overrideReason!,
                style:
                    const TextStyle(color: RiderPalette.amber, fontSize: 11)),
          ],
          if (recognitions.hasAny) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                if (recognitions.foundingRider.awarded)
                  _RecognitionLabel(
                    'Founding Rider ${recognitions.foundingRider.numberLabel(4)}',
                  ),
                if (recognitions.legend.awarded)
                  _RecognitionLabel(
                    'Legend ${recognitions.legend.numberLabel(4)}',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RecognitionLabel extends StatelessWidget {
  const _RecognitionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label.trim(),
        style: const TextStyle(
          color: RiderPalette.blue,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: .2,
        ),
      );
}

class _TodaySection extends StatelessWidget {
  const _TodaySection({required this.earnings});

  final Map<String, dynamic> earnings;

  @override
  Widget build(BuildContext context) {
    final summary = RiderEarningsSummary.from(earnings);
    final today = _number(earnings['todayEarnings'] ??
        earnings['todayClearedCash'] ??
        earnings['availableToday']);
    final jobs = _number(
            earnings['todayCompletedJobs'] ?? earnings['completedJobsToday'])
        .toInt();
    final pending = _number(earnings['pendingEarnings'] ??
        earnings['pendingBalance'] ??
        summary?.pending);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SmallLabel("Today's earnings"),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TodayTile(
                icon: Icons.payments_outlined,
                color: RiderPalette.green,
                value: '£${today.toStringAsFixed(2)}',
                label: "Today's earnings",
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _TodayTile(
                icon: Icons.done_rounded,
                color: RiderPalette.blue,
                value: '$jobs',
                label: 'Completed jobs',
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _TodayTile(
                icon: Icons.schedule_rounded,
                color: RiderPalette.amber,
                value: '£${pending.toStringAsFixed(2)}',
                label: 'Pending payouts',
              ),
            ),
          ],
        ),
      ],
    );
  }

  static double _number(Object? value) => value is num ? value.toDouble() : 0;
}

class _TodayTile extends StatelessWidget {
  const _TodayTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      radius: 16,
      blur: 14,
      opacity: .60,
      edgeColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: RiderPalette.paper,
                fontFamily: RiderTypography.mono,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: RiderPalette.muted,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityJobsCard extends StatelessWidget {
  const _PriorityJobsCard({
    required this.online,
    required this.offers,
    required this.onTap,
  });

  final bool online;
  final List<Map<String, dynamic>> offers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = offers.length;
    final title = !online
        ? 'Go online for jobs'
        : count == 0
            ? 'No deliveries available'
            : '$count eligible ${count == 1 ? 'job' : 'jobs'}';
    final message = !online
        ? 'Go online to receive eligible delivery offers.'
        : count == 0
            ? 'New offers will appear here automatically.'
            : 'Open delivery offers to review the swipeable card stack.';
    return _ActionRow(
      icon: Icons.map_outlined,
      iconColor: RiderPalette.blue,
      title: title,
      subtitle: message,
      onTap: onTap,
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.job, required this.onTap});

  final Map<String, dynamic>? job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (job == null) {
      return _EmptyPanel(
        icon: Icons.calendar_month_outlined,
        title: 'No scheduled deliveries',
        message: 'Reserved jobs will appear here with their collection window.',
        action: 'Open schedule',
        onTap: onTap,
      );
    }

    return RiderGlassSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      opacity: .64,
      edgeColor: RiderPalette.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SCHEDULED',
            style: TextStyle(
              color: RiderPalette.purple,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _route(job!),
            style: const TextStyle(
              color: RiderPalette.paper,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${job!['pickupWindow'] ?? job!['scheduledTime'] ?? _formatTime(job!['scheduledAt']) ?? 'Collection time pending'}',
            style: const TextStyle(color: RiderPalette.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.items, required this.onTap});

  final List<Map<String, dynamic>> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.history_rounded,
        title: 'Complete your first delivery to see your activity here.',
        message: 'Completed jobs will appear here automatically.',
      );
    }

    return RiderGlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      opacity: .62,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _RecentRow(item: items[i], onTap: onTap),
            if (i != items.length - 1)
              Divider(color: Colors.white.withValues(alpha: .07), height: 1),
          ],
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: RiderPalette.green.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.done_rounded,
                  color: RiderPalette.green, size: 18),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['serviceType'] ?? item['deliveryType'] ?? 'Delivery'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RiderPalette.paper,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item['dropoffArea'] ?? item['dropoffPostcode'] ?? item['pickupArea'] ?? 'Completed'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RiderPalette.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _money(item['riderEarning'] ?? item['riderPay']),
              style: const TextStyle(
                color: RiderPalette.paper,
                fontFamily: RiderTypography.mono,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.work_outline_rounded,
            label: 'Jobs',
            onTap: () => onSelectTab(1),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _QuickAction(
            icon: Icons.calendar_month_outlined,
            label: 'Schedule',
            onTap: () => onSelectTab(2),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _QuickAction(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Earnings',
            onTap: () => onSelectTab(3),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      onTap: onTap,
      radius: 16,
      blur: 14,
      opacity: .58,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: RiderPalette.blue, size: 19),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: RiderPalette.paper,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      radius: 20,
      opacity: .64,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: RiderPalette.paper,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style:
                      const TextStyle(color: RiderPalette.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: RiderPalette.muted),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      radius: 20,
      opacity: .60,
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: RiderPalette.blue.withValues(alpha: .12),
              shape: BoxShape.circle,
              border: Border.all(
                color: RiderPalette.blue.withValues(alpha: .25),
              ),
            ),
            child: Icon(icon, color: RiderPalette.blue, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: RiderPalette.paper,
              fontFamily: RiderTypography.heading,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: RiderPalette.muted,
              height: 1.45,
              fontSize: 12.5,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 8),
            Text(
              action!,
              style: const TextStyle(
                color: RiderPalette.blue,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      padding: const EdgeInsets.all(14),
      radius: 16,
      blur: 10,
      opacity: .58,
      edgeColor: RiderPalette.amber,
      child: Row(
        children: [
          Icon(icon, color: RiderPalette.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: RiderPalette.paper,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 3),
                Text(message,
                    style: const TextStyle(
                        color: RiderPalette.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: RiderPalette.paper,
              fontFamily: RiderTypography.heading,
              fontSize: 19,
              height: 1.1,
            ),
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: const TextStyle(
                color: RiderPalette.blue,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _SmallLabel extends StatelessWidget {
  const _SmallLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF5F6779),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: .9,
        ),
      ),
    );
  }
}

String _route(Map<String, dynamic> item) {
  final pickup = item['pickupArea'] ??
      item['pickupPostcode'] ??
      item['pickupShortAddress'] ??
      'Pickup';
  final dropoff = item['dropoffArea'] ??
      item['dropoffPostcode'] ??
      item['dropoffShortAddress'] ??
      'Drop-off';
  return '$pickup → $dropoff';
}

String? _formatTime(Object? value) {
  if (value is! Timestamp) return null;
  final local = value.toDate().toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return 'Collection window $hour:$minute';
}

String _money(Object? value) =>
    value is num ? '£${value.toStringAsFixed(2)}' : '—';

class _RankProgressData {
  const _RankProgressData({
    required this.progress,
    required this.remaining,
    required this.nextRank,
  });

  final double progress;
  final int remaining;
  final String? nextRank;

  static _RankProgressData forTrust(int trustPoints) {
    var index = 0;
    for (var i = 0; i < RiderRankSnapshot.thresholds.length; i++) {
      if (trustPoints >= RiderRankSnapshot.thresholds[i]) index = i;
    }
    if (index == RiderRankSnapshot.ranks.length - 1) {
      return const _RankProgressData(
        progress: 1,
        remaining: 0,
        nextRank: null,
      );
    }
    final current = RiderRankSnapshot.thresholds[index];
    final next = RiderRankSnapshot.thresholds[index + 1];
    return _RankProgressData(
      progress: ((trustPoints - current) / (next - current)).clamp(0.0, 1.0),
      remaining: (next - trustPoints).clamp(0, next),
      nextRank: RiderRankSnapshot.ranks[index + 1],
    );
  }
}
