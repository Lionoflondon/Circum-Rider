import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:url_launcher/url_launcher.dart';

import '../account/view/account_details.dart';
import '../account/view/earnings.dart';
import '../authentication/bloc/auth_bloc.dart';
import '../founder_access/founder_rider_access.dart';
import '../history/view/history.dart';
import '../notifications/rider_notifications_view.dart';
import '../rider_account/rider_account_state.dart';
import '../rider_design/rider_ui.dart';
import '../rider_truth/rider_truth.dart';
import '../support/view/support.dart';
import '../verification/view/verification.dart';

class RiderProfileView extends StatelessWidget {
  const RiderProfileView({super.key, required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const RiderEmptyState(
        icon: Icons.lock_outline,
        title: 'Sign in required',
        message: 'Sign in to view your Rider profile.',
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('riderProfiles')
          .doc(user.uid)
          .snapshots(),
      builder: (context, profileSnapshot) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('riders')
              .doc(user.uid)
              .snapshots(),
          builder: (context, riderSnapshot) {
            if (!profileSnapshot.hasData && !riderSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: RiderPalette.blue),
              );
            }
            final rider = riderSnapshot.data?.data() ?? const {};
            final riderProfile = profileSnapshot.data?.data() ?? const {};
            final profile = <String, dynamic>{...rider, ...riderProfile};
            final accountState = RiderAccountStateResolver.resolveRecords(
              rider: rider,
              riderProfile: riderProfile,
            );
            final vehicles = _ProfileData.vehicles(profile);
            final readiness = RiderReadinessSnapshot.from(
              profile: profile,
              accountState: accountState,
              vehicles: vehicles,
            );
            return CustomScrollView(
              key: const PageStorageKey('rider-profile-hub'),
              slivers: [
                SliverSafeArea(
                  bottom: false,
                  sliver: SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                    sliver: SliverList.list(
                      children: [
                        const _ProfileTitle(),
                        const SizedBox(height: 10),
                        const FounderRiderBadge(),
                        const SizedBox(height: 14),
                        _IdentityHubCard(
                          user: user,
                          profile: profile,
                          accountState: accountState,
                          readiness: readiness,
                        ),
                        const SizedBox(height: 14),
                        _RestrictedStatusCard(
                          accountState: accountState,
                          readiness: readiness,
                        ),
                        _ReadinessCard(readiness: readiness),
                        const SizedBox(height: 18),
                        _WorkPreferencesSection(
                          uid: user.uid,
                          profile: profile,
                        ),
                        const SizedBox(height: 18),
                        _VehiclesSection(uid: user.uid, vehicles: vehicles),
                        const SizedBox(height: 18),
                        _DocumentsSection(profile: profile),
                        const SizedBox(height: 18),
                        const _PermissionsSection(),
                        const SizedBox(height: 18),
                        _SafetySupportSection(onSelectTab: onSelectTab),
                        const SizedBox(height: 18),
                        _PerformanceSection(profile: profile),
                        const SizedBox(height: 18),
                        _EarningsPayoutsSection(onSelectTab: onSelectTab),
                        const SizedBox(height: 18),
                        _AccountLegalSection(onSelectTab: onSelectTab),
                        const SizedBox(height: 18),
                        _SignOutButton(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class RiderReadinessSnapshot {
  const RiderReadinessSnapshot({
    required this.state,
    required this.summary,
    required this.items,
  });

  final String state;
  final String summary;
  final List<RiderReadinessItem> items;

  bool get ready => state == 'Ready to work';

  static RiderReadinessSnapshot from({
    required Map<String, dynamic> profile,
    required RiderAccountState accountState,
    required List<RiderVehicleSnapshot> vehicles,
  }) {
    final approved = accountState == RiderAccountState.approved;
    final restricted = {
      RiderAccountState.suspended,
      RiderAccountState.frozen,
      RiderAccountState.closed,
    }.contains(accountState);
    final pending = {
      RiderAccountState.submitted,
      RiderAccountState.pendingReview,
    }.contains(accountState);
    final primaryVehicle = vehicles.firstOrNull;
    final vehicleReady =
        primaryVehicle != null && primaryVehicle.type.trim().isNotEmpty;
    final registrationReady = primaryVehicle == null
        ? false
        : !primaryVehicle.registrationRequired ||
            (primaryVehicle.registration?.trim().isNotEmpty ?? false);
    final docsApproved = profile['documentsVerified'] == true ||
        _statusApproved(profile['documentStatus']) ||
        _statusApproved(profile['verificationStatus']);
    final identityVerified = profile['identityVerified'] == true ||
        _statusApproved(profile['identityStatus']);
    final payoutReady = _statusApproved(profile['stripeConnectStatus']) ||
        _statusApproved(profile['payoutAccountStatus']) ||
        profile['payoutsEnabled'] == true;
    final items = [
      RiderReadinessItem(
        icon: Icons.verified_user_outlined,
        title: 'Identity verified',
        status: identityVerified ? 'Ready' : 'Action required',
        complete: identityVerified,
        fix: VerificationView(),
      ),
      RiderReadinessItem(
        icon: Icons.home_work_outlined,
        title: 'Home address completed',
        status: _hasAny(profile, const ['homeAddress', 'address'])
            ? 'Ready'
            : 'Action required',
        complete: _hasAny(profile, const ['homeAddress', 'address']),
        fix: const AccountDetails(),
      ),
      RiderReadinessItem(
        icon: Icons.two_wheeler_rounded,
        title: 'Active vehicle available',
        status: vehicleReady ? 'Ready' : 'Action required',
        complete: vehicleReady,
        fix: VerificationView(),
      ),
      RiderReadinessItem(
        icon: Icons.pin_rounded,
        title: 'Vehicle registration',
        status: registrationReady ? 'Ready' : 'Action required',
        complete: registrationReady,
        fix: VerificationView(),
      ),
      RiderReadinessItem(
        icon: Icons.description_outlined,
        title: 'Required documents approved',
        status: docsApproved ? 'Ready' : 'Under review',
        complete: docsApproved,
        fix: VerificationView(),
      ),
      const RiderReadinessItem(
        icon: Icons.location_on_outlined,
        title: 'Location permission',
        status: 'Check device',
        complete: true,
        fix: null,
      ),
      const RiderReadinessItem(
        icon: Icons.notifications_none_rounded,
        title: 'Notifications permission',
        status: 'Check device',
        complete: true,
        fix: null,
      ),
      RiderReadinessItem(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Payout setup',
        status: payoutReady ? 'Ready' : 'Setup required',
        complete: payoutReady,
        fix: const EarningsView(),
      ),
      RiderReadinessItem(
        icon: Icons.admin_panel_settings_outlined,
        title: 'Account approved',
        status: approved
            ? 'Ready'
            : pending
                ? 'Under review'
                : restricted
                    ? 'Restricted'
                    : 'Action required',
        complete: approved,
        fix: null,
      ),
    ];
    final state = restricted
        ? 'Account restricted'
        : pending
            ? 'Approval pending'
            : items.every((item) => item.complete)
                ? 'Ready to work'
                : 'Action required';
    return RiderReadinessSnapshot(
      state: state,
      summary: state == 'Ready to work'
          ? 'Your Rider account is ready for eligible offers.'
          : 'Review the items below before going online.',
      items: items,
    );
  }

  static bool _statusApproved(Object? value) {
    final text = '$value'.trim().toLowerCase();
    return text == 'approved' || text == 'verified' || text == 'ready';
  }

  static bool _hasAny(Map<String, dynamic> data, List<String> keys) =>
      keys.any((key) => '${data[key] ?? ''}'.trim().isNotEmpty);
}

class RiderReadinessItem {
  const RiderReadinessItem({
    required this.icon,
    required this.title,
    required this.status,
    required this.complete,
    this.fix,
  });

  final IconData icon;
  final String title;
  final String status;
  final bool complete;
  final Widget? fix;
}

class _ProfileData {
  static List<RiderVehicleSnapshot> vehicles(Map<String, dynamic> profile) {
    final values = <Map<String, dynamic>>[];
    final rawVehicles = profile['vehicles'];
    if (rawVehicles is Iterable) {
      for (final value in rawVehicles.take(2)) {
        if (value is Map) values.add(Map<String, dynamic>.from(value));
      }
    }
    if (values.isEmpty && profile['vehicle'] is Map) {
      values.add(Map<String, dynamic>.from(profile['vehicle'] as Map));
    }
    if (values.isEmpty && '${profile['vehicleType'] ?? ''}'.trim().isNotEmpty) {
      values.add({
        'type': profile['vehicleType'],
        'make': profile['vehicleMake'],
        'model': profile['vehicleModel'] ?? profile['vehicleMakeModel'],
        'colour': profile['vehicleColour'],
        'registration': profile['vehicleRegistration'] ??
            profile['registration'] ??
            profile['plateNumber'],
        'verificationStatus':
            profile['vehicleVerificationStatus'] ?? profile['vehicleStatus'],
        'primary': true,
      });
    }
    return values.indexed
        .map((entry) => RiderVehicleSnapshot.from(
              entry.$2,
              primary: entry.$1 == 0 || entry.$2['primary'] == true,
            ))
        .toList(growable: false);
  }

  static String statusLabel(RiderAccountState state) =>
      RiderAccountStateResolver.storageValue(state).replaceAll('_', ' ');

  static String name(User user, Map<String, dynamic> profile) {
    final first = '${profile['firstName'] ?? ''}'.trim();
    final last = '${profile['lastName'] ?? ''}'.trim();
    final full = '${profile['name'] ?? profile['fullName'] ?? ''}'.trim();
    final joined = [first, last].where((part) => part.isNotEmpty).join(' ');
    return joined.isNotEmpty
        ? joined
        : full.isNotEmpty
            ? full
            : user.displayName ?? 'Circum Rider';
  }

  static String initials(String name) {
    final parts = name.split(' ').where((part) => part.isNotEmpty).take(2);
    final initials = parts.map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? 'R' : initials;
  }
}

class _ProfileTitle extends StatelessWidget {
  const _ProfileTitle();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operations & Account',
            style: TextStyle(
              color: RiderPalette.paper,
              fontFamily: RiderTypography.heading,
              fontSize: 31,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage your readiness, vehicles, documents and Rider tools.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .62),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      );
}

class _IdentityHubCard extends StatelessWidget {
  const _IdentityHubCard({
    required this.user,
    required this.profile,
    required this.accountState,
    required this.readiness,
  });

  final User user;
  final Map<String, dynamic> profile;
  final RiderAccountState accountState;
  final RiderReadinessSnapshot readiness;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final name = _ProfileData.name(user, profile);
    final photo =
        '${profile['profilePhoto'] ?? auth.profilePhoto ?? user.photoURL ?? ''}'
            .trim();
    final rank = RiderRankSnapshot.from(profile);
    final email = '${profile['email'] ?? user.email ?? ''}'.trim();
    final phone =
        '${profile['phone'] ?? profile['phoneNumber'] ?? user.phoneNumber ?? ''}'
            .trim();
    final vehicle = _ProfileData.vehicles(profile).firstOrNull;
    return RiderGlassSurface(
      padding: const EdgeInsets.all(18),
      radius: 28,
      opacity: .62,
      blur: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: RiderPalette.blue.withValues(alpha: .16),
                backgroundImage:
                    photo.isEmpty ? null : CachedNetworkImageProvider(photo),
                child: photo.isEmpty
                    ? Text(
                        _ProfileData.initials(name),
                        style: const TextStyle(
                          color: RiderPalette.paper,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RiderPalette.paper,
                        fontFamily: RiderTypography.heading,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        RiderStatusBadge(
                          _ProfileData.statusLabel(accountState).toUpperCase(),
                          color: readiness.ready
                              ? RiderPalette.green
                              : accountState == RiderAccountState.approved
                                  ? RiderPalette.amber
                                  : RiderPalette.red,
                        ),
                        RiderStatusBadge(
                          readiness.state.toUpperCase(),
                          color: readiness.ready
                              ? RiderPalette.green
                              : RiderPalette.amber,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit profile',
                onPressed: () => _open(context, const AccountDetails()),
                icon: const Icon(Icons.edit_rounded, color: RiderPalette.blue),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _IdentityDetail(icon: Icons.email_outlined, label: email),
          _IdentityDetail(
              icon: Icons.phone_iphone_rounded,
              label: phone.isEmpty ? 'Phone not supplied' : phone),
          _IdentityDetail(
            icon: Icons.badge_outlined,
            label: 'Rider ID ${user.uid}',
            mono: true,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: RiderMetric(
                  value: rank == null ? 'Updating' : rank.rank,
                  label: 'CURRENT RANK',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RiderMetric(
                  value: rank == null ? '—' : '${rank.trustPoints}',
                  label: 'TRUST POINTS',
                ),
              ),
            ],
          ),
          if (rank != null) ...[
            const SizedBox(height: 12),
            RiderRankProgress(rank: rank.rank, trustPoints: rank.trustPoints),
          ],
          const SizedBox(height: 12),
          _IdentityDetail(
            icon: Icons.two_wheeler_rounded,
            label: vehicle == null
                ? 'Primary vehicle not supplied'
                : [
                    vehicle.type,
                    vehicle.makeModel,
                    vehicle.registration,
                  ].whereType<String>().where((v) => v.isNotEmpty).join(' · '),
            mono: vehicle?.registration != null,
          ),
        ],
      ),
    );
  }
}

class _IdentityDetail extends StatelessWidget {
  const _IdentityDetail({
    required this.icon,
    required this.label,
    this.mono = false,
  });

  final IconData icon;
  final String label;
  final bool mono;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            Icon(icon, color: RiderPalette.blue, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .72),
                  fontFamily: mono ? RiderTypography.mono : null,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class _RestrictedStatusCard extends StatelessWidget {
  const _RestrictedStatusCard({
    required this.accountState,
    required this.readiness,
  });

  final RiderAccountState accountState;
  final RiderReadinessSnapshot readiness;

  @override
  Widget build(BuildContext context) {
    if (readiness.ready) return const SizedBox.shrink();
    final restricted = {
      RiderAccountState.suspended,
      RiderAccountState.frozen,
      RiderAccountState.closed,
      RiderAccountState.rejected,
    }.contains(accountState);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: RiderGlassSurface(
        padding: const EdgeInsets.all(15),
        radius: 22,
        opacity: .72,
        borderColor: (restricted ? RiderPalette.red : RiderPalette.amber)
            .withValues(alpha: .34),
        edgeColor: restricted ? RiderPalette.red : RiderPalette.amber,
        child: Row(
          children: [
            Icon(
              restricted ? Icons.block_rounded : Icons.info_outline_rounded,
              color: restricted ? RiderPalette.red : RiderPalette.amber,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    readiness.state,
                    style: const TextStyle(
                      color: RiderPalette.paper,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    restricted
                        ? 'You can view account information, but operational actions may be blocked.'
                        : readiness.summary,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .66),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _open(context, const SupportView()),
              child: const Text('Support'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.readiness});

  final RiderReadinessSnapshot readiness;

  @override
  Widget build(BuildContext context) => _HubSection(
        title: 'Ready to work',
        subtitle: readiness.summary,
        icon: Icons.task_alt_rounded,
        trailing: RiderStatusBadge(
          readiness.state.toUpperCase(),
          color: readiness.ready ? RiderPalette.green : RiderPalette.amber,
        ),
        children: readiness.items
            .map(
              (item) => _HubRow(
                icon: item.icon,
                title: item.title,
                subtitle: item.status,
                statusColor:
                    item.complete ? RiderPalette.green : RiderPalette.amber,
                onTap:
                    item.fix == null ? null : () => _open(context, item.fix!),
              ),
            )
            .toList(),
      );
}

class _WorkPreferencesSection extends StatefulWidget {
  const _WorkPreferencesSection({
    required this.uid,
    required this.profile,
  });

  final String uid;
  final Map<String, dynamic> profile;

  @override
  State<_WorkPreferencesSection> createState() =>
      _WorkPreferencesSectionState();
}

class _WorkPreferencesSectionState extends State<_WorkPreferencesSection> {
  bool _saving = false;

  Map<String, dynamic> get _prefs =>
      Map<String, dynamic>.from(widget.profile['workPreferences'] is Map
          ? widget.profile['workPreferences'] as Map
          : const {});

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    final vehicle = _ProfileData.vehicles(widget.profile).firstOrNull;
    return _HubSection(
      title: 'Work preferences',
      subtitle:
          'Guide eligible offers without overriding safety, IRIS or admin rules.',
      icon: Icons.tune_rounded,
      children: [
        _HubRow(
          icon: Icons.map_outlined,
          title: 'Preferred working areas',
          subtitle: _listLabel(prefs['areas'], fallback: 'Not set'),
          onTap: () => _editTextList('Preferred working areas', 'areas'),
        ),
        _HubRow(
          icon: Icons.route_rounded,
          title: 'Delivery distance preference',
          subtitle: '${prefs['maxDistanceMiles'] ?? 'Any eligible'} miles',
          onTap: () =>
              _editNumber('Delivery distance preference', 'maxDistanceMiles'),
        ),
        _PreferenceSwitch(
          title: 'Immediate jobs',
          subtitle: 'Receive live offers when online',
          value: prefs['immediateJobs'] != false,
          onChanged: (value) => _save({'immediateJobs': value}),
        ),
        _PreferenceSwitch(
          title: 'Scheduled jobs',
          subtitle: 'See reservable future deliveries',
          value: prefs['scheduledJobs'] != false,
          onChanged: (value) => _save({'scheduledJobs': value}),
        ),
        ...[
          'Express',
          'Business',
          'Gift',
          'Health+',
          'Vanguard',
          'Heavy Duty',
        ].map(
          (label) => _PreferenceSwitch(
            title: '$label delivery preference',
            subtitle: 'Preference only; eligibility still applies',
            value: prefs[_key(label)] == true,
            onChanged: (value) => _save({_key(label): value}),
          ),
        ),
        _HubRow(
          icon: Icons.calendar_month_rounded,
          title: 'Preferred working days',
          subtitle: _listLabel(prefs['workingDays'], fallback: 'Not set'),
          onTap: () => _editTextList('Preferred working days', 'workingDays'),
        ),
        _HubRow(
          icon: Icons.access_time_rounded,
          title: 'Preferred working hours',
          subtitle: '${prefs['workingHours'] ?? 'Not set'}',
          onTap: () => _editText('Preferred working hours', 'workingHours'),
        ),
        _HubRow(
          icon: Icons.two_wheeler_rounded,
          title: 'Preferred vehicle for offers',
          subtitle:
              '${prefs['preferredVehicle'] ?? vehicle?.type ?? 'Not set'}',
          onTap: () => _editText('Preferred vehicle', 'preferredVehicle'),
        ),
        _HubRow(
          icon: Icons.radio_button_checked_rounded,
          title: 'Availability status',
          subtitle:
              '${widget.profile['availabilityStatus'] ?? widget.profile['status'] ?? 'Unknown'}',
          onTap: null,
        ),
        if (_saving)
          const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(color: RiderPalette.blue),
          ),
      ],
    );
  }

  static String _key(String label) =>
      '${label.toLowerCase().replaceAll('+', 'plus').replaceAll(' ', '')}Enabled';

  String _listLabel(Object? value, {required String fallback}) {
    if (value is Iterable && value.isNotEmpty) return value.join(', ');
    final text = '$value'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  Future<void> _editText(String title, String key) async {
    final controller = TextEditingController(text: '${_prefs[key] ?? ''}');
    final value = await _showTextDialog(title, controller);
    controller.dispose();
    if (value == null) return;
    await _save({key: value});
  }

  Future<void> _editNumber(String title, String key) async {
    final controller = TextEditingController(text: '${_prefs[key] ?? ''}');
    final value = await _showTextDialog(title, controller, number: true);
    controller.dispose();
    if (value == null) return;
    await _save({key: num.tryParse(value) ?? value});
  }

  Future<void> _editTextList(String title, String key) async {
    final current = _prefs[key];
    final controller = TextEditingController(
      text: current is Iterable ? current.join(', ') : '${current ?? ''}',
    );
    final value = await _showTextDialog(title, controller);
    controller.dispose();
    if (value == null) return;
    await _save({
      key: value
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList(),
    });
  }

  Future<String?> _showTextDialog(
    String title,
    TextEditingController controller, {
    bool number = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _save(Map<String, dynamic> patch) async {
    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{};
      for (final entry in patch.entries) {
        updates['workPreferences.${entry.key}'] = entry.value;
      }
      updates['workPreferences.updatedAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance
          .collection('riderProfiles')
          .doc(widget.uid)
          .set(updates, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: RiderPalette.blue,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(
          title,
          style: const TextStyle(
            color: RiderPalette.paper,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: RiderPalette.muted, fontSize: 12),
        ),
      );
}

class _VehiclesSection extends StatelessWidget {
  const _VehiclesSection({required this.uid, required this.vehicles});

  final String uid;
  final List<RiderVehicleSnapshot> vehicles;

  @override
  Widget build(BuildContext context) => _HubSection(
        title: 'Vehicles',
        subtitle: 'Manage up to two vehicles for eligible offers.',
        icon: Icons.two_wheeler_rounded,
        children: [
          if (vehicles.isEmpty)
            _HubRow(
              icon: Icons.add_circle_outline_rounded,
              title: 'Add your first vehicle',
              subtitle: 'Vehicle details are required before work',
              statusColor: RiderPalette.amber,
              onTap: () => _open(context, VerificationView()),
            )
          else
            ...vehicles.indexed.map(
              (entry) => _VehicleCard(
                uid: uid,
                index: entry.$1,
                vehicle: entry.$2,
              ),
            ),
          if (vehicles.length < 2)
            _HubRow(
              icon: Icons.add_rounded,
              title: 'Add another vehicle',
              subtitle: 'Second vehicle support',
              onTap: () => _open(context, VerificationView()),
            ),
        ],
      );
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.uid,
    required this.index,
    required this.vehicle,
  });

  final String uid;
  final int index;
  final RiderVehicleSnapshot vehicle;

  @override
  Widget build(BuildContext context) {
    final missingPlate =
        vehicle.registrationRequired && vehicle.registration == null;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                vehicle.type.toLowerCase().contains('car') ||
                        vehicle.type.toLowerCase().contains('van')
                    ? Icons.directions_car_rounded
                    : Icons.two_wheeler_rounded,
                color: RiderPalette.blue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  vehicle.type.isEmpty
                      ? 'Vehicle details incomplete'
                      : [
                          vehicle.type,
                          vehicle.makeModel,
                          vehicle.colour,
                        ]
                          .whereType<String>()
                          .where((item) => item.trim().isNotEmpty)
                          .join(' · '),
                  style: const TextStyle(
                    color: RiderPalette.paper,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              RiderStatusBadge(
                vehicle.primary ? 'PRIMARY' : 'SECONDARY',
                color: vehicle.primary ? RiderPalette.blue : RiderPalette.muted,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            missingPlate
                ? 'Registration required'
                : (vehicle.registration ?? 'No registration required'),
            style: TextStyle(
              color: missingPlate ? RiderPalette.red : RiderPalette.muted,
              fontFamily: RiderTypography.mono,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RiderStatusBadge(
                vehicle.status,
                color: vehicle.status == 'VERIFIED'
                    ? RiderPalette.green
                    : missingPlate
                        ? RiderPalette.red
                        : RiderPalette.amber,
              ),
              RiderStatusBadge(
                'Capability: ${vehicle.type.isEmpty ? 'Pending' : vehicle.type}',
                color: RiderPalette.blue,
              ),
              RiderStatusBadge('Evidence: ${vehicle.status}',
                  color: vehicle.status == 'VERIFIED'
                      ? RiderPalette.green
                      : RiderPalette.amber),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: () => _open(context, VerificationView()),
                child: const Text('View vehicle'),
              ),
              TextButton(
                onPressed: () => _open(context, VerificationView()),
                child: const Text('Edit vehicle'),
              ),
              TextButton(
                onPressed: () => _open(context, VerificationView()),
                child: const Text('Upload evidence'),
              ),
              if (!vehicle.primary)
                TextButton(
                  onPressed: () => _setPrimary(index),
                  child: const Text('Set active'),
                ),
              TextButton(
                onPressed: () => _confirmRemove(context),
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setPrimary(int index) async {
    await FirebaseFirestore.instance.collection('riderProfiles').doc(uid).set({
      'activeVehicleIndex': index,
      'vehiclesUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove vehicle?'),
        content: const Text(
          'This only removes the vehicle from your Rider profile after confirmation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove == true) {
      await FirebaseFirestore.instance
          .collection('riderProfiles')
          .doc(uid)
          .set({
        'vehicleRemovalRequestedAt': FieldValue.serverTimestamp(),
        'vehicleRemovalRequestedIndex': index,
      }, SetOptions(merge: true));
    }
  }
}

class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection({required this.profile});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) => _HubSection(
        title: 'Documents',
        subtitle: 'Verification evidence and review status.',
        icon: Icons.folder_copy_outlined,
        children: [
          _DocumentRow(
            title: 'Identity',
            status: _docStatus(profile, 'identityStatus', 'identityVerified'),
            reason: profile['identityRejectionReason'],
          ),
          _DocumentRow(
            title: 'Right to work',
            status:
                _docStatus(profile, 'rightToWorkStatus', 'rightToWorkVerified'),
            reason: profile['rightToWorkRejectionReason'],
          ),
          _DocumentRow(
            title: 'Vehicle evidence',
            status: _docStatus(profile, 'vehicleRegistrationDocumentStatus',
                'vehicleDocumentsVerified'),
            reason: profile['vehicleDocumentRejectionReason'],
          ),
          _DocumentRow(
            title: 'Insurance',
            status: _docStatus(profile, 'insuranceStatus', 'insuranceVerified'),
            reason: profile['insuranceRejectionReason'],
          ),
          _DocumentRow(
            title: 'Additional verification',
            status: _docStatus(
                profile, 'additionalVerificationStatus', 'documentsVerified'),
            reason: profile['additionalVerificationReason'],
          ),
        ],
      );

  static String _docStatus(Map<String, dynamic> profile, String statusKey,
      [String? booleanKey]) {
    if (booleanKey != null && profile[booleanKey] == true) return 'Approved';
    final text = '${profile[statusKey] ?? ''}'.trim().toLowerCase();
    return switch (text) {
      'approved' || 'verified' => 'Approved',
      'submitted' => 'Submitted',
      'under_review' || 'pending' || 'reviewing' => 'Under review',
      'rejected' || 'declined' => 'Rejected',
      'expired' => 'Expired',
      'expiring_soon' => 'Expiring soon',
      _ => 'Not supplied',
    };
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.title,
    required this.status,
    this.reason,
  });

  final String title;
  final String status;
  final Object? reason;

  @override
  Widget build(BuildContext context) => _HubRow(
        icon: Icons.description_outlined,
        title: title,
        subtitle: reason == null || status != 'Rejected'
            ? status
            : '$status · $reason',
        statusColor: _color(status),
        onTap: () => _open(context, VerificationView()),
      );

  static Color _color(String status) => switch (status) {
        'Approved' => RiderPalette.green,
        'Rejected' || 'Expired' => RiderPalette.red,
        'Submitted' || 'Under review' || 'Expiring soon' => RiderPalette.amber,
        _ => RiderPalette.muted,
      };
}

class _PermissionsSection extends StatelessWidget {
  const _PermissionsSection();

  @override
  Widget build(BuildContext context) => const _HubSection(
        title: 'App permissions',
        subtitle: 'Live delivery tools depend on device permissions.',
        icon: Icons.phonelink_lock_outlined,
        children: [
          _PermissionRow(
            title: 'Precise location',
            reason: 'Used for active delivery tracking and arrival checks.',
            type: _PermissionType.location,
            priority: true,
          ),
          _PermissionRow(
            title: 'Background location',
            reason: 'Keeps active delivery tracking alive when supported.',
            type: _PermissionType.backgroundLocation,
            priority: true,
          ),
          _PermissionRow(
            title: 'Notifications',
            reason: 'Used for jobs, delivery updates and account actions.',
            type: _PermissionType.notifications,
          ),
          _PermissionRow(
            title: 'Camera',
            reason: 'Used for parcel and handover evidence.',
            type: _PermissionType.camera,
          ),
          _PermissionRow(
            title: 'Photos or files',
            reason: 'Used when uploading document or delivery evidence.',
            type: _PermissionType.photos,
          ),
          _PermissionRow(
            title: 'Phone and calls',
            reason: 'Uses your device dialler for permitted delivery calls.',
            type: _PermissionType.phone,
          ),
        ],
      );
}

enum _PermissionType {
  location,
  backgroundLocation,
  notifications,
  camera,
  photos,
  phone,
}

class _PermissionRow extends StatefulWidget {
  const _PermissionRow({
    required this.title,
    required this.reason,
    required this.type,
    this.priority = false,
  });

  final String title;
  final String reason;
  final _PermissionType type;
  final bool priority;

  @override
  State<_PermissionRow> createState() => _PermissionRowState();
}

class _PermissionRowState extends State<_PermissionRow> {
  String _status = 'Checking';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await _read();
    if (mounted) setState(() => _status = status);
  }

  Future<String> _read() async {
    switch (widget.type) {
      case _PermissionType.location:
        if (!await Geolocator.isLocationServiceEnabled()) {
          return 'Disabled';
        }
        final permission = await Geolocator.checkPermission();
        return switch (permission) {
          LocationPermission.always => 'Allowed',
          LocationPermission.whileInUse => 'Limited',
          LocationPermission.denied => 'Not requested',
          LocationPermission.deniedForever => 'Denied',
          LocationPermission.unableToDetermine => 'Unavailable',
        };
      case _PermissionType.backgroundLocation:
        final permission = await Geolocator.checkPermission();
        return switch (permission) {
          LocationPermission.always => 'Allowed',
          LocationPermission.whileInUse => 'Foreground only',
          LocationPermission.denied => 'Not requested',
          LocationPermission.deniedForever => 'Denied',
          LocationPermission.unableToDetermine => 'Unavailable',
        };
      case _PermissionType.notifications:
        return _permissionStatus(
            await permissions.Permission.notification.status);
      case _PermissionType.camera:
        return _permissionStatus(await permissions.Permission.camera.status);
      case _PermissionType.photos:
        return _permissionStatus(await permissions.Permission.photos.status);
      case _PermissionType.phone:
        return 'Uses device dialler';
    }
  }

  @override
  Widget build(BuildContext context) => _HubRow(
        icon: widget.priority
            ? Icons.location_searching_rounded
            : Icons.check_circle_outline_rounded,
        title: widget.title,
        subtitle: '$_status · ${widget.reason}',
        statusColor: _status == 'Allowed'
            ? RiderPalette.green
            : _status == 'Denied' || _status == 'Disabled'
                ? RiderPalette.red
                : RiderPalette.amber,
        onTap: _request,
      );

  Future<void> _request() async {
    switch (widget.type) {
      case _PermissionType.location:
      case _PermissionType.backgroundLocation:
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        } else if (permission == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        } else {
          await Geolocator.openLocationSettings();
        }
        break;
      case _PermissionType.notifications:
        await permissions.Permission.notification.request();
        break;
      case _PermissionType.camera:
        await permissions.Permission.camera.request();
        break;
      case _PermissionType.photos:
        await permissions.Permission.photos.request();
        break;
      case _PermissionType.phone:
        await launchUrl(Uri.parse('tel:'));
        break;
    }
    await _load();
  }

  static String _permissionStatus(permissions.PermissionStatus status) {
    if (status.isGranted) return 'Allowed';
    if (status.isLimited) return 'Limited';
    if (status.isDenied) return 'Not requested';
    if (status.isPermanentlyDenied) return 'Denied';
    return 'Unavailable';
  }
}

class _SafetySupportSection extends StatelessWidget {
  const _SafetySupportSection({required this.onSelectTab});
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) => _HubSection(
        title: 'Safety & support',
        subtitle: 'Operational help without exposing admin controls.',
        icon: Icons.health_and_safety_outlined,
        children: [
          _HubRow(
            icon: Icons.sos_rounded,
            title: 'Emergency help',
            subtitle: 'Open Rider Support before any emergency escalation',
            statusColor: RiderPalette.red,
            onTap: () => _confirmEmergency(context),
          ),
          _HubRow(
            icon: Icons.report_problem_outlined,
            title: 'Report a safety issue',
            subtitle: 'Dangerous delivery, customer concern or incident',
            onTap: () => _open(context, const SupportView()),
          ),
          _HubRow(
            icon: Icons.support_agent_rounded,
            title: 'Delivery support',
            subtitle: 'Get help with an active or recent delivery',
            onTap: () => _open(context, const SupportView()),
          ),
          _HubRow(
            icon: Icons.accessibility_new_rounded,
            title: 'Accessibility',
            subtitle: 'Use device accessibility settings with Circum Rider',
            onTap: () => _open(context, const SupportView()),
          ),
          _HubRow(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy controls',
            subtitle: 'Manage account data and privacy requests',
            onTap: () => _open(context, const AccountDetails()),
          ),
          _HubRow(
            icon: Icons.menu_book_outlined,
            title: 'Safety guidance',
            subtitle: 'Read Circum Rider safety guidance',
            onTap: () => launchUrl(Uri.parse('https://circumuk.com/terms')),
          ),
        ],
      );

  Future<void> _confirmEmergency(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open emergency help?'),
        content: const Text(
          'Circum can open Rider Support. This does not replace emergency services.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open support'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      _open(context, const SupportView());
    }
  }
}

class _PerformanceSection extends StatelessWidget {
  const _PerformanceSection({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final rank = RiderRankSnapshot.from(profile);
    final deliveries = profile['completedDeliveries'];
    final rating = profile['averageRating'] ?? profile['rating'];
    final reliability = profile['reliabilityScore'];
    return _HubSection(
      title: 'Performance',
      subtitle: 'Only backend-supported performance records are shown.',
      icon: Icons.insights_rounded,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: [
              RiderMetric(
                value:
                    deliveries is num ? '${deliveries.toInt()}' : 'Unavailable',
                label: 'DELIVERIES',
              ),
              RiderMetric(
                value: rank == null ? 'Updating' : rank.rank,
                label: 'RANK',
              ),
              RiderMetric(
                value: rank == null ? '—' : '${rank.trustPoints}',
                label: 'TRUST',
              ),
              RiderMetric(
                value: rating is num
                    ? '★ ${rating.toStringAsFixed(2)}'
                    : reliability is num
                        ? '${reliability.toStringAsFixed(0)}%'
                        : 'Unavailable',
                label: rating is num ? 'RATING' : 'RELIABILITY',
              ),
            ],
          ),
        ),
        _HubRow(
          icon: Icons.history_rounded,
          title: 'Recent delivery activity',
          subtitle: 'Open completed delivery history',
          onTap: () => _open(context, const HistoryView()),
        ),
        const _HubRow(
          icon: Icons.flag_outlined,
          title: 'Account milestones',
          subtitle: 'Joined, approved and delivery progress where available',
          onTap: null,
        ),
      ],
    );
  }
}

class _EarningsPayoutsSection extends StatelessWidget {
  const _EarningsPayoutsSection({required this.onSelectTab});
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) => _HubSection(
        title: 'Earnings and payouts',
        subtitle: 'Cash records, withdrawals and payout support.',
        icon: Icons.account_balance_wallet_outlined,
        children: [
          _HubRow(
            icon: Icons.payments_outlined,
            title: 'Earnings',
            subtitle: 'Available earnings, pending earnings and summaries',
            onTap: () => onSelectTab(3),
          ),
          _HubRow(
            icon: Icons.pending_actions_rounded,
            title: 'Payout status',
            subtitle: 'Withdrawal processing, paid or failed states',
            onTap: () => _open(context, const EarningsView()),
          ),
          _HubRow(
            icon: Icons.receipt_long_outlined,
            title: 'Payout history',
            subtitle: 'Paid withdrawals and transaction history',
            onTap: () => _open(context, const EarningsView()),
          ),
          _HubRow(
            icon: Icons.list_alt_rounded,
            title: 'Transaction history',
            subtitle:
                'Delivery earnings, tips, adjustments and waiting charges',
            onTap: () => _open(context, const EarningsView()),
          ),
          _HubRow(
            icon: Icons.settings_outlined,
            title: 'Payment or payout setup',
            subtitle: 'Manage the existing Stripe Connect payout flow',
            onTap: () => _open(context, const EarningsView()),
          ),
          _HubRow(
            icon: Icons.support_agent_rounded,
            title: 'Earnings support',
            subtitle: 'Questions about adjustments, tips or waiting charges',
            onTap: () => _open(context, const SupportView()),
          ),
        ],
      );
}

class _AccountLegalSection extends StatelessWidget {
  const _AccountLegalSection({required this.onSelectTab});
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) => _HubSection(
        title: 'Account and legal',
        subtitle: 'Account access, preferences and Rider terms.',
        icon: Icons.manage_accounts_outlined,
        children: [
          _HubRow(
            icon: Icons.person_outline_rounded,
            title: 'Personal details',
            subtitle: 'Name, profile photo and customer-facing identity',
            onTap: () => _open(context, const AccountDetails()),
          ),
          _HubRow(
            icon: Icons.contact_mail_outlined,
            title: 'Contact details',
            subtitle: 'Email, phone and home address',
            onTap: () => _open(context, const AccountDetails()),
          ),
          _HubRow(
            icon: Icons.notifications_none_rounded,
            title: 'Notification preferences',
            subtitle: 'Notification Centre and preference management',
            onTap: () => _open(
              context,
              RiderNotificationsView(onNavigateTab: onSelectTab),
            ),
          ),
          _HubRow(
            icon: Icons.accessibility_new_rounded,
            title: 'Accessibility',
            subtitle: 'Rider accessibility support',
            onTap: () => _open(context, const SupportView()),
          ),
          _HubRow(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy',
            subtitle: 'Privacy policy and controls',
            onTap: () => launchUrl(Uri.parse('https://circumuk.com/privacy')),
          ),
          _HubRow(
            icon: Icons.gavel_rounded,
            title: 'Terms',
            subtitle: 'Circum terms',
            onTap: () => launchUrl(Uri.parse('https://circumuk.com/terms')),
          ),
          _HubRow(
            icon: Icons.assignment_outlined,
            title: 'Rider agreement',
            subtitle: 'Rider operating terms',
            onTap: () => launchUrl(Uri.parse('https://circumuk.com/terms')),
          ),
          _HubRow(
            icon: Icons.dataset_outlined,
            title: 'Data controls',
            subtitle: 'Access, deletion and privacy requests',
            onTap: () => _open(context, const AccountDetails()),
          ),
          _HubRow(
            icon: Icons.delete_outline_rounded,
            title: 'Close account',
            subtitle: 'Requires confirmation before any action',
            statusColor: RiderPalette.red,
            onTap: () => _open(context, const AccountDetails()),
          ),
        ],
      );
}

class _SignOutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () => _confirmSignOut(context),
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Sign out'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: RiderPalette.red,
          side: BorderSide(color: RiderPalette.red.withValues(alpha: .35)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      );

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in with your Rider account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(SignOut());
    }
  }
}

class _HubSection extends StatelessWidget {
  const _HubSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => RiderGlassSurface(
        padding: EdgeInsets.zero,
        radius: 26,
        opacity: .62,
        blur: 20,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 14, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: RiderPalette.blue.withValues(alpha: .15),
                      border: Border.all(
                        color: RiderPalette.blue.withValues(alpha: .30),
                      ),
                    ),
                    child: Icon(icon, color: RiderPalette.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: RiderPalette.paper,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .58),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
            ...children,
            const SizedBox(height: 8),
          ],
        ),
      );
}

class _HubRow extends StatelessWidget {
  const _HubRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.statusColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        minTileHeight: 58,
        leading: Icon(icon, color: statusColor ?? RiderPalette.blue),
        title: Text(
          title,
          style: const TextStyle(
            color: RiderPalette.paper,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: RiderPalette.muted, fontSize: 12),
        ),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right_rounded,
                color: RiderPalette.muted),
      );
}

void _open(BuildContext context, Widget page) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}
