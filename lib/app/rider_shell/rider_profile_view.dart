import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../account/view/account_details.dart';
import '../authentication/bloc/auth_bloc.dart';
import '../founder_access/founder_rider_access.dart';
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
            return CustomScrollView(
              key: const PageStorageKey('rider-personal-profile'),
              slivers: [
                SliverSafeArea(
                  bottom: false,
                  sliver: SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 96),
                    sliver: SliverList.list(
                      children: [
                        const _ProfileTitle(),
                        const SizedBox(height: 10),
                        const FounderRiderBadge(),
                        const SizedBox(height: 12),
                        _UnifiedProfileSurface(
                          user: user,
                          profile: profile,
                          accountState: accountState,
                          onSelectTab: onSelectTab,
                        ),
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

class _ProfileData {
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

  static String accountStatus(RiderAccountState state) =>
      RiderAccountStateResolver.storageValue(state).replaceAll('_', ' ');

  static String documentSummary(Map<String, dynamic> profile) {
    final statuses = [
      _docStatus(profile, 'identityStatus', 'identityVerified'),
      _docStatus(profile, 'vehicleRegistrationDocumentStatus',
          'vehicleDocumentsVerified'),
      _docStatus(profile, 'insuranceStatus', 'insuranceVerified'),
      _docStatus(profile, 'additionalVerificationStatus', 'documentsVerified'),
    ];
    final attention = statuses
        .where((status) =>
            status == 'Not supplied' ||
            status == 'Rejected' ||
            status == 'Expired')
        .length;
    if (attention > 0) return '$attention items need attention';
    if (statuses.any((status) => status == 'Under review')) {
      return 'Some items are under review';
    }
    if (statuses.every((status) => status == 'Approved')) return 'Approved';
    return 'Review your documents';
  }

  static String vehicleSummary(Map<String, dynamic> profile) {
    final type = '${profile['vehicleType'] ?? ''}'.trim();
    final registration =
        '${profile['vehicleRegistration'] ?? profile['registration'] ?? profile['plateNumber'] ?? ''}'
            .trim();
    final vehicle = profile['vehicle'];
    if (vehicle is Map) {
      final vehicleType =
          '${vehicle['type'] ?? vehicle['vehicleType'] ?? ''}'.trim();
      final plate =
          '${vehicle['registration'] ?? vehicle['plateNumber'] ?? ''}'.trim();
      if (vehicleType.isNotEmpty && plate.isNotEmpty) {
        return '$vehicleType · $plate';
      }
      if (vehicleType.isNotEmpty) return '$vehicleType · Registration required';
    }
    if (type.isNotEmpty && registration.isNotEmpty) {
      return '$type · $registration';
    }
    if (type.isNotEmpty) return '$type · Registration required';
    return 'Add or manage vehicles';
  }

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
      _ => 'Not supplied',
    };
  }
}

class _ProfileTitle extends StatelessWidget {
  const _ProfileTitle();

  @override
  Widget build(BuildContext context) => const Text(
        'Profile',
        style: TextStyle(
          color: RiderPalette.paper,
          fontFamily: RiderTypography.heading,
          fontSize: 32,
        ),
      );
}

class _UnifiedProfileSurface extends StatelessWidget {
  const _UnifiedProfileSurface({
    required this.user,
    required this.profile,
    required this.accountState,
    required this.onSelectTab,
  });

  final User user;
  final Map<String, dynamic> profile;
  final RiderAccountState accountState;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final name = _ProfileData.name(user, profile);
    final photo =
        '${profile['profilePhoto'] ?? auth.profilePhoto ?? user.photoURL ?? ''}'
            .trim();
    final rank = RiderRankSnapshot.from(profile);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0D111C).withValues(alpha: .72),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                child: _ProfileHeader(
                  name: name,
                  photo: photo,
                  initials: _ProfileData.initials(name),
                  rank: rank?.rank ?? 'Rank updating',
                  trust: rank == null
                      ? 'Trust updating'
                      : '${rank.trustPoints} trust points',
                  accountStatus: _ProfileData.accountStatus(accountState),
                ),
              ),
              const _SoftDivider(),
              _ProfileGroup(
                title: 'Your profile',
                rows: [
                  _ProfileRow(
                    icon: Icons.person_outline_rounded,
                    title: 'Personal details',
                    subtitle: 'Name, email, phone and Rider ID',
                    onTap: () => _open(context, const AccountDetails()),
                  ),
                  _ProfileRow(
                    icon: Icons.two_wheeler_rounded,
                    title: 'Vehicles',
                    subtitle: _ProfileData.vehicleSummary(profile),
                    onTap: () => _open(context, VerificationView()),
                  ),
                  _ProfileRow(
                    icon: Icons.folder_copy_outlined,
                    title: 'Documents',
                    subtitle: _ProfileData.documentSummary(profile),
                    onTap: () => _open(context, VerificationView()),
                  ),
                ],
              ),
              const _SoftDivider(),
              _ProfileGroup(
                title: 'Preferences',
                rows: [
                  _ProfileRow(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    subtitle: 'Job alerts and delivery updates',
                    onTap: () => _open(
                      context,
                      RiderNotificationsView(onNavigateTab: onSelectTab),
                    ),
                  ),
                  _ProfileRow(
                    icon: Icons.accessibility_new_rounded,
                    title: 'Accessibility',
                    subtitle: 'Display and accessibility support',
                    onTap: () => _open(context, const SupportView()),
                  ),
                ],
              ),
              const _SoftDivider(),
              _ProfileGroup(
                title: 'Help',
                rows: [
                  _ProfileRow(
                    icon: Icons.support_agent_rounded,
                    title: 'Support',
                    subtitle: 'Contact Rider Support',
                    onTap: () => _open(context, const SupportView()),
                  ),
                  _ProfileRow(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Safety guidance',
                    subtitle: 'Delivery safety and incident help',
                    onTap: () =>
                        launchUrl(Uri.parse('https://circumuk.com/terms')),
                  ),
                ],
              ),
              const _SoftDivider(),
              _ProfileGroup(
                title: 'About and account',
                rows: [
                  _ProfileRow(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy',
                    subtitle: 'Privacy policy and data controls',
                    onTap: () =>
                        launchUrl(Uri.parse('https://circumuk.com/privacy')),
                  ),
                  _ProfileRow(
                    icon: Icons.gavel_rounded,
                    title: 'Terms',
                    subtitle: 'Circum terms',
                    onTap: () =>
                        launchUrl(Uri.parse('https://circumuk.com/terms')),
                  ),
                  _ProfileRow(
                    icon: Icons.assignment_outlined,
                    title: 'Rider agreement',
                    subtitle: 'Rider operating terms',
                    onTap: () =>
                        launchUrl(Uri.parse('https://circumuk.com/terms')),
                  ),
                  _ProfileRow(
                    icon: Icons.delete_outline_rounded,
                    title: 'Close account',
                    subtitle: 'Manage account closure',
                    onTap: () => _open(context, const AccountDetails()),
                  ),
                  _ProfileRow(
                    icon: Icons.logout_rounded,
                    title: 'Sign out',
                    subtitle: 'Leave this Rider session',
                    destructive: true,
                    onTap: () => _confirmSignOut(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.photo,
    required this.initials,
    required this.rank,
    required this.trust,
    required this.accountStatus,
  });

  final String name;
  final String photo;
  final String initials;
  final String rank;
  final String trust;
  final String accountStatus;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: RiderPalette.blue.withValues(alpha: .16),
            backgroundImage:
                photo.isEmpty ? null : CachedNetworkImageProvider(photo),
            child: photo.isEmpty
                ? Text(
                    initials,
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
                    fontSize: 25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$rank · $trust',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RiderPalette.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Account status · $accountStatus',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RiderPalette.muted,
                    fontSize: 12,
                  ),
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
      );
}

class _ProfileGroup extends StatelessWidget {
  const _ProfileGroup({required this.title, required this.rows});

  final String title;
  final List<_ProfileRow> rows;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .50),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
            ),
            const SizedBox(height: 4),
            ...rows,
          ],
        ),
      );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        minTileHeight: 58,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(
          icon,
          color: destructive ? RiderPalette.red : RiderPalette.blue,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: destructive ? RiderPalette.red : RiderPalette.paper,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: RiderPalette.muted, fontSize: 12),
        ),
        trailing: onTap == null
            ? null
            : const Icon(
                Icons.chevron_right_rounded,
                color: RiderPalette.muted,
              ),
      );
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        indent: 18,
        endIndent: 18,
        color: Colors.white.withValues(alpha: .055),
      );
}

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

void _open(BuildContext context, Widget page) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}
