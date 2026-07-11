import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../account/view/account_details.dart';
import '../authentication/bloc/auth_bloc.dart';
import '../history/view/history.dart';
import '../notifications/rider_notifications_view.dart';
import '../rider_design/rider_ui.dart';
import '../support/view/support.dart';
import '../verification/view/verification.dart';

class RiderProfileView extends StatelessWidget {
  const RiderProfileView({super.key, required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const RiderEmptyState(
        icon: Icons.lock_outline,
        title: 'Sign in required',
        message: 'Sign in to view your Rider profile.',
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
            if (!profileSnapshot.hasData && !riderSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final profile = <String, dynamic>{
              ...?riderSnapshot.data?.data(),
              ...?profileSnapshot.data?.data(),
            };
            return CustomScrollView(
              key: const PageStorageKey('rider-profile'),
              slivers: [
                SliverSafeArea(
                  bottom: false,
                  sliver: SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                    sliver: SliverList.list(children: [
                      const Text('Rider profile',
                          style: TextStyle(
                              color: RiderPalette.paper,
                              fontFamily: RiderTypography.heading,
                              fontSize: 30)),
                      const SizedBox(height: 16),
                      _IdentityCard(profile: profile),
                      const SizedBox(height: 14),
                      RiderGlassCard(
                        child: RiderRankProgress(
                          rank:
                              '${profile['riderRank'] ?? profile['rank'] ?? 'Agent'}',
                          trustPoints: _int(profile['trustPoints']),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Performance(profile: profile),
                      const SizedBox(height: 22),
                      const RiderSectionTitle('Vehicles'),
                      const SizedBox(height: 10),
                      _Vehicles(profile: profile),
                      const SizedBox(height: 22),
                      const RiderSectionTitle('Rider account'),
                      const SizedBox(height: 10),
                      RiderGlassCard(
                        padding: EdgeInsets.zero,
                        child: Column(children: [
                          _ProfileAction(
                            icon: Icons.person_outline_rounded,
                            title: 'Personal details',
                            onTap: () => _open(context, const AccountDetails()),
                          ),
                          _ProfileAction(
                            icon: Icons.verified_user_outlined,
                            title: 'Documents and verification',
                            subtitle: _documentStatus(profile),
                            onTap: () => _open(context, VerificationView()),
                          ),
                          _ProfileAction(
                            icon: Icons.notifications_none_rounded,
                            title: 'Notifications',
                            onTap: () =>
                                _open(context, const RiderNotificationsView()),
                          ),
                          _ProfileAction(
                            icon: Icons.history_rounded,
                            title: 'Delivery activity',
                            onTap: () => _open(context, const HistoryView()),
                          ),
                          _ProfileAction(
                            icon: Icons.support_agent_rounded,
                            title: 'Support',
                            onTap: () => _open(context, const SupportView()),
                          ),
                          _ProfileAction(
                            icon: Icons.gavel_rounded,
                            title: 'Legal',
                            onTap: () => launchUrl(
                                Uri.parse('https://circumuk.com/terms')),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.read<AuthBloc>().add(SignOut()),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign out'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          foregroundColor: RiderPalette.red,
                          side: BorderSide(
                              color: RiderPalette.red.withOpacity(.35)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;
  static void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  static String _documentStatus(Map<String, dynamic> profile) =>
      profile['documentsVerified'] == true ? 'Verified' : 'Review status';
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final name =
        '${profile['name'] ?? profile['fullName'] ?? auth.username ?? 'Circum Rider'}'
            .trim();
    final first = '${profile['firstName'] ?? ''}'.trim();
    final last = '${profile['lastName'] ?? ''}'.trim();
    final resolvedName =
        name == 'Circum Rider' && (first.isNotEmpty || last.isNotEmpty)
            ? '$first $last'.trim()
            : name;
    final photo =
        '${profile['profilePhoto'] ?? auth.profilePhoto ?? ''}'.trim();
    final active = _approved(profile);
    return RiderGlassCard(
      child: Row(children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: RiderPalette.blue.withOpacity(.14),
          backgroundImage:
              photo.isEmpty ? null : CachedNetworkImageProvider(photo),
          child: photo.isEmpty
              ? Text(_initials(resolvedName),
                  style: const TextStyle(
                      color: RiderPalette.paper,
                      fontSize: 20,
                      fontWeight: FontWeight.w800))
              : null,
        ),
        const SizedBox(width: 15),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(resolvedName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: RiderPalette.paper,
                    fontFamily: RiderTypography.heading,
                    fontSize: 23)),
            const SizedBox(height: 7),
            RiderStatusBadge(active ? 'VERIFIED RIDER' : 'ACCOUNT REVIEW',
                color: active ? RiderPalette.green : RiderPalette.amber),
          ]),
        ),
      ]),
    );
  }

  static bool _approved(Map<String, dynamic> profile) => [
        profile['approvalStatus'],
        profile['accountStatus'],
        profile['onboardingStatus'],
      ].any((value) => '$value'.toLowerCase() == 'approved');

  static String _initials(String name) {
    final parts = name.split(' ').where((part) => part.isNotEmpty).take(2);
    return parts.map((part) => part[0].toUpperCase()).join();
  }
}

class _Performance extends StatelessWidget {
  const _Performance({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final rating = profile['averageRating'] ?? profile['rating'];
    final jobs = profile['completedDeliveries'] ?? profile['totalTrips'];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      childAspectRatio: 2.15,
      children: [
        RiderMetric(
            value: rating is num ? '★ ${rating.toStringAsFixed(2)}' : '—',
            label: 'RATING'),
        RiderMetric(value: jobs is num ? '$jobs' : '—', label: 'DELIVERIES'),
      ],
    );
  }
}

class _Vehicles extends StatelessWidget {
  const _Vehicles({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final vehicles = <Map<String, dynamic>>[];
    final rawVehicles = profile['vehicles'];
    if (rawVehicles is Iterable) {
      for (final value in rawVehicles.take(2)) {
        if (value is Map) vehicles.add(Map<String, dynamic>.from(value));
      }
    }
    if (vehicles.isEmpty && profile['vehicle'] is Map) {
      vehicles.add(Map<String, dynamic>.from(profile['vehicle'] as Map));
    }
    if (vehicles.isEmpty &&
        '${profile['vehicleType'] ?? ''}'.trim().isNotEmpty) {
      vehicles.add({
        'type': profile['vehicleType'],
        'registration':
            profile['vehicleRegistration'] ?? profile['registration'],
      });
    }
    if (vehicles.isEmpty) {
      return const RiderEmptyState(
        icon: Icons.two_wheeler_rounded,
        title: 'No registered vehicle',
        message: 'Your approved vehicles will appear here.',
      );
    }
    return Column(
      children: vehicles
          .map((vehicle) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RiderGlassCard(
                  child: Row(children: [
                    const Icon(Icons.two_wheeler_rounded,
                        color: RiderPalette.blue),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${vehicle['type'] ?? vehicle['vehicleType'] ?? 'Vehicle'}',
                                style: const TextStyle(
                                    color: RiderPalette.paper,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(
                                '${vehicle['registration'] ?? vehicle['registrationPlate'] ?? vehicle['plate'] ?? 'No registration required'}',
                                style: const TextStyle(
                                    color: RiderPalette.muted,
                                    fontFamily: RiderTypography.mono,
                                    fontSize: 12)),
                          ]),
                    ),
                    RiderStatusBadge(
                      vehicle['verified'] == true ? 'VERIFIED' : 'REGISTERED',
                      color: vehicle['verified'] == true
                          ? RiderPalette.green
                          : RiderPalette.blue,
                    ),
                  ]),
                ),
              ))
          .toList(),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        minTileHeight: 58,
        leading: Icon(icon, color: RiderPalette.blue),
        title: Text(title,
            style: const TextStyle(
                color: RiderPalette.paper, fontWeight: FontWeight.w700)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!,
                style:
                    const TextStyle(color: RiderPalette.muted, fontSize: 11)),
        trailing:
            const Icon(Icons.chevron_right_rounded, color: RiderPalette.muted),
      );
}
