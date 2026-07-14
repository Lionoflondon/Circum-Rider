import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../account/view/account_details.dart';
import '../authentication/bloc/auth_bloc.dart';
import '../notifications/rider_notifications_view.dart';
import '../onboarding/rider_application_centre.dart';
import '../onboarding/rider_guide_view.dart';
import '../rider_account/rider_account_state.dart';
import '../rider_design/rider_ui.dart';
import '../rider_truth/rider_truth.dart';
import '../support/view/support.dart';
import '../verification/view/verification.dart';

class RiderProfileView extends StatefulWidget {
  const RiderProfileView({super.key, required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  @override
  State<RiderProfileView> createState() => _RiderProfileViewState();
}

class _RiderProfileViewState extends State<RiderProfileView> {
  int _reload = 0;

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
      key: ValueKey('rider-profile-main-$_reload'),
      stream: FirebaseFirestore.instance
          .collection('riderProfiles')
          .doc(user.uid)
          .snapshots(),
      builder: (context, profileSnapshot) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          key: ValueKey('rider-profile-rider-$_reload'),
          stream: FirebaseFirestore.instance
              .collection('riders')
              .doc(user.uid)
              .snapshots(),
          builder: (context, riderSnapshot) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              key: ValueKey('rider-profile-earnings-$_reload'),
              stream: FirebaseFirestore.instance
                  .collection('riderEarnings')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, earningsSnapshot) {
                if (profileSnapshot.hasError ||
                    riderSnapshot.hasError ||
                    earningsSnapshot.hasError) {
                  return _ProfileError(
                      onRetry: () => setState(() => _reload++));
                }
                if (!profileSnapshot.hasData && !riderSnapshot.hasData) {
                  return const _ProfileLoading();
                }
                final profile = <String, dynamic>{
                  ...?riderSnapshot.data?.data(),
                  ...?profileSnapshot.data?.data(),
                };
                final earnings =
                    earningsSnapshot.data?.data() ?? const <String, dynamic>{};
                return _RiderProfileScreen(
                  user: user,
                  profile: profile,
                  earnings: earnings,
                  onSelectTab: widget.onSelectTab,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RiderProfileScreen extends StatelessWidget {
  const _RiderProfileScreen({
    required this.user,
    required this.profile,
    required this.earnings,
    required this.onSelectTab,
  });

  final User user;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> earnings;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final data =
        _RiderProfileData(user: user, profile: profile, earnings: earnings);

    return CustomScrollView(
      key: const PageStorageKey('rider-profile-screen'),
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 112),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProfileHero(
                        data: data,
                        onEditPhoto: () =>
                            _open(context, const AccountDetails()),
                        onEditProfile: () =>
                            _open(context, const AccountDetails()),
                      ),
                      const SizedBox(height: 16),
                      _StatsRow(data: data),
                      const SizedBox(height: 22),
                      _ProfileSection(
                        title: 'Account',
                        rows: [
                          _ProfileRow(
                            icon: Icons.badge_outlined,
                            title: 'Personal Details',
                            description:
                                'Legal name, date of birth and Rider ID',
                            onTap: () => _open(context, const AccountDetails()),
                          ),
                          _ProfileRow(
                            icon: Icons.contact_phone_outlined,
                            title: 'Contact Information',
                            description: data.contactSummary,
                            onTap: () => _open(context, const AccountDetails()),
                          ),
                          _ProfileRow(
                            icon: Icons.health_and_safety_outlined,
                            title: 'Emergency Contact',
                            description: data.emergencyContactSummary,
                            onTap: () =>
                                _open(context, const RiderApplicationCentre()),
                          ),
                        ],
                      ),
                      _ProfileSection(
                        title: 'Work',
                        rows: [
                          _ProfileRow(
                            icon: Icons.two_wheeler_outlined,
                            title: 'Vehicles',
                            description: data.vehicleSummary,
                            onTap: () => _open(context, VerificationView()),
                          ),
                          _ProfileRow(
                            icon: Icons.verified_user_outlined,
                            title: 'Documents',
                            description: data.documentSummary,
                            onTap: () => _open(context, VerificationView()),
                          ),
                          _ProfileRow(
                            icon: Icons.event_available_outlined,
                            title: 'Availability',
                            description: data.availabilitySummary,
                            onTap: () => onSelectTab(0),
                          ),
                        ],
                      ),
                      _ProfileSection(
                        title: 'Finance',
                        rows: [
                          _ProfileRow(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Earnings',
                            description:
                                'Cash earnings and delivery transactions',
                            onTap: () => onSelectTab(3),
                          ),
                          _ProfileRow(
                            icon: Icons.diamond_outlined,
                            title: 'Roth Wallet',
                            description: data.rothSummary,
                            onTap: () =>
                                _open(context, const RiderApplicationCentre()),
                          ),
                          _ProfileRow(
                            icon: Icons.payments_outlined,
                            title: 'Stripe Payouts',
                            description:
                                'Manage payouts through Stripe Connect',
                            onTap: () => onSelectTab(3),
                          ),
                          _ProfileRow(
                            icon: Icons.verified_outlined,
                            title: 'Stripe Verification Status',
                            description: data.stripeStatus,
                            statusColor: data.stripeStatusColor,
                            onTap: () => onSelectTab(3),
                          ),
                          _ProfileRow(
                            icon: Icons.savings_outlined,
                            title: 'Available Balance',
                            description: data.availableBalance,
                            onTap: () => onSelectTab(3),
                          ),
                          _ProfileRow(
                            icon: Icons.schedule_outlined,
                            title: 'Next Estimated Payout',
                            description: data.nextPayout,
                            onTap: () => onSelectTab(3),
                          ),
                          _ProfileRow(
                            icon: Icons.receipt_long_outlined,
                            title: 'Payout History',
                            description: 'Stripe Connect payout records',
                            onTap: () => onSelectTab(3),
                          ),
                          _ProfileRow(
                            icon: Icons.list_alt_outlined,
                            title: 'Transaction History',
                            description: 'Delivery, tip and adjustment records',
                            onTap: () => onSelectTab(3),
                          ),
                        ],
                      ),
                      _ProfileSection(
                        title: 'Performance',
                        rows: [
                          _ProfileRow(
                            icon: Icons.military_tech_outlined,
                            title: 'Current Rank',
                            description: data.rank,
                            onTap: () => onSelectTab(0),
                          ),
                          _ProfileRow(
                            icon: Icons.trending_up_outlined,
                            title: 'Rank Progress',
                            description: data.rankProgress,
                            onTap: () => onSelectTab(0),
                          ),
                          _ProfileRow(
                            icon: Icons.auto_awesome_outlined,
                            title: 'Trust Progress',
                            description: data.trustProgress,
                            onTap: () => onSelectTab(0),
                          ),
                          _ProfileRow(
                            icon: Icons.workspace_premium_outlined,
                            title: 'Achievements',
                            description: data.achievementsSummary,
                            onTap: () => onSelectTab(0),
                          ),
                        ],
                      ),
                      _ProfileSection(
                        title: 'Settings',
                        rows: [
                          _ProfileRow(
                            icon: Icons.notifications_none_rounded,
                            title: 'Notifications',
                            description:
                                'Job offers, messages and Rider updates',
                            onTap: () => _open(
                              context,
                              RiderNotificationsView(
                                  onNavigateTab: onSelectTab),
                            ),
                          ),
                          _ProfileRow(
                            icon: Icons.accessibility_new_outlined,
                            title: 'Accessibility',
                            description:
                                'Text, contrast and motion preferences',
                            onTap: () =>
                                _open(context, const RiderApplicationCentre()),
                          ),
                          _ProfileRow(
                            icon: Icons.lock_outline,
                            title: 'Privacy',
                            description: 'Your data and account controls',
                            onTap: () => _open(context,
                                const RiderLegalView(initial: 'Privacy')),
                          ),
                          _ProfileRow(
                            icon: Icons.assignment_outlined,
                            title: 'Rider Agreement',
                            description: 'Your Rider operating agreement',
                            onTap: () => _open(
                                context,
                                const RiderLegalView(
                                    initial: 'Rider Agreement')),
                          ),
                          _ProfileRow(
                            icon: Icons.help_outline_rounded,
                            title: 'Support',
                            description: 'Get help from Circum Support',
                            onTap: () => _open(context, const SupportView()),
                          ),
                          _ProfileRow(
                            icon: Icons.shield_outlined,
                            title: 'Safety Centre',
                            description: 'Guidance for safe deliveries',
                            onTap: () => _open(
                              context,
                              RiderGuideView(
                                authenticated: true,
                                progress: RiderApprovalProgress.fromBackend(
                                  accountExists: true,
                                  firebaseEmailVerified: user.emailVerified,
                                  rider: profile,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      _ProfileSection(
                        title: 'Account Actions',
                        rows: [
                          _ProfileRow(
                            icon: Icons.logout_rounded,
                            title: 'Sign Out',
                            description: 'Leave this device securely',
                            tone: _ProfileRowTone.danger,
                            onTap: () => _confirmSignOut(context),
                          ),
                          _ProfileRow(
                            icon: Icons.delete_forever_outlined,
                            title: 'Close Account',
                            description:
                                'Permanently delete your Circum account and personal data.',
                            tone: _ProfileRowTone.danger,
                            onTap: () => _confirmCloseAccount(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RiderProfileData {
  _RiderProfileData({
    required this.user,
    required this.profile,
    required this.earnings,
  })  : rankSnapshot = RiderRankSnapshot.from(profile),
        earningsSummary = RiderEarningsSummary.from(earnings);

  final User user;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> earnings;
  final RiderRankSnapshot? rankSnapshot;
  final RiderEarningsSummary? earningsSummary;

  String get name {
    final first = text('firstName');
    final last = text('lastName');
    final joined = [first, last].where((part) => part.isNotEmpty).join(' ');
    if (joined.isNotEmpty) return joined;
    final full = text('name', fallback: text('fullName'));
    if (full.isNotEmpty) return full;
    return user.displayName ?? 'Circum Rider';
  }

  String get handle {
    final raw = text('handle',
        fallback: text('riderHandle', fallback: text('username')));
    if (raw.isNotEmpty) return raw.startsWith('@') ? raw : '@$raw';
    final derived = name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '.')
        .replaceAll(RegExp(r'^\.+|\.+$'), '');
    return derived.isEmpty ? '@rider' : '@$derived';
  }

  String get initials {
    final parts = name.split(' ').where((part) => part.isNotEmpty).take(2);
    final value = parts.map((part) => part[0].toUpperCase()).join();
    return value.isEmpty ? 'R' : value;
  }

  String get photoUrl => text('profilePhotoUrl',
      fallback: text('profilePhoto',
          fallback: text('photoURL',
              fallback: text('photoUrl', fallback: user.photoURL ?? ''))));

  String get verifiedLabel {
    final value = text('verificationStatus',
            fallback: text('approvalStatus', fallback: text('accountStatus')))
        .toLowerCase();
    if (profile['documentsVerified'] == true ||
        profile['identityVerified'] == true ||
        value == 'verified' ||
        value == 'approved') {
      return 'Verified';
    }
    if (value.contains('review') || value.contains('pending')) {
      return 'Under review';
    }
    if (value.contains('reject')) return 'Needs attention';
    if (value.contains('suspend')) return 'Suspended';
    return 'Verification pending';
  }

  String get rank => rankSnapshot?.rank ?? 'Rank pending';
  int get trustPoints =>
      rankSnapshot?.trustPoints ?? number('trustPoints').round();

  String get memberSince {
    final created = timestamp('createdAt') ??
        timestamp('submittedAt') ??
        user.metadata.creationTime;
    if (created == null) return 'Member since pending';
    return 'Member since ${_monthYear(created)}';
  }

  String get deliveriesCompleted => whole('completedDeliveries',
      fallback: whole('deliveriesCompleted',
          fallback: whole('completedJobs', fallback: '0')));

  String get customerRating {
    final rating = number('rating', fallback: number('customerRating'));
    return rating <= 0 ? 'New' : rating.toStringAsFixed(1);
  }

  String get acceptanceRate => percent('acceptanceRate');
  String get onTimeRate =>
      percent('onTimeRate', fallbackKey: 'onTimeDeliveryRate');

  String get contactSummary {
    final phone = text('phoneNumber',
        fallback: text('phone', fallback: user.phoneNumber ?? ''));
    final email = text('email', fallback: user.email ?? '');
    if (phone.isNotEmpty && email.isNotEmpty) return 'Phone and email saved';
    if (phone.isNotEmpty) return 'Phone saved';
    if (email.isNotEmpty) return 'Email saved';
    return 'Add phone and email';
  }

  String get emergencyContactSummary {
    final name = text('emergencyContactName');
    final phone = text('emergencyContactPhone');
    if (name.isNotEmpty && phone.isNotEmpty) return '$name · phone saved';
    if (name.isNotEmpty) return '$name · add phone';
    return 'Add emergency contact';
  }

  String get vehicleSummary {
    final vehicles = profile['vehicles'];
    if (vehicles is List && vehicles.isNotEmpty) {
      return '${vehicles.length} vehicle${vehicles.length == 1 ? '' : 's'} saved';
    }
    final type = text('vehicleType', fallback: text('typeOfVehicle'));
    return type.isEmpty ? 'Add vehicle details' : type;
  }

  String get documentSummary {
    if (profile['documentsVerified'] == true) return 'Documents verified';
    final status = text('documentStatus',
        fallback: text('verificationStatus', fallback: text('identityStatus')));
    if (status.isEmpty) return 'Identity and vehicle documents';
    return _prettyStatus(status);
  }

  String get availabilitySummary {
    final status = text('availabilityStatus',
        fallback: text('driverStatus', fallback: text('status')));
    if (status.isEmpty) return 'Manage online availability';
    return _prettyStatus(status);
  }

  String get rothSummary {
    final status = text('rothOnboardingStatus',
        fallback: profile['rothWalletId'] == null ? '' : 'connected');
    if (status.isEmpty) return 'Separate from cash earnings';
    return '${_prettyStatus(status)} · separate from payouts';
  }

  String get stripeStatus {
    final status = text('stripeConnectStatus',
        fallback:
            text('payoutStatus', fallback: text('stripeVerificationStatus')));
    if (status.isEmpty) return 'Stripe Connect setup required';
    return _prettyStatus(status);
  }

  Color get stripeStatusColor {
    final value = stripeStatus.toLowerCase();
    if (value.contains('verified') || value.contains('active')) {
      return RiderPalette.green;
    }
    if (value.contains('action') || value.contains('required')) {
      return RiderPalette.red;
    }
    return RiderPalette.amber;
  }

  String get availableBalance =>
      _money(earningsSummary?.available ?? moneyValue('availableBalance'));

  String get nextPayout {
    final value = timestampFromAny(earnings['nextEstimatedPayoutAt'] ??
        earnings['nextPayoutAt'] ??
        profile['nextEstimatedPayoutAt']);
    if (value == null) return 'Estimated by Stripe Connect';
    return _shortDate(value);
  }

  String get rankProgress {
    if (rankSnapshot == null) return 'Build trust to unlock rank progress';
    final current = rankSnapshot!.trustPoints;
    const thresholds = RiderRankSnapshot.thresholds;
    const ranks = RiderRankSnapshot.ranks;
    final index = ranks.indexOf(rankSnapshot!.rank);
    if (index < 0 || index >= ranks.length - 1) return 'Highest rank achieved';
    final next = thresholds[index + 1];
    return '${(next - current).clamp(0, next)} trust points to ${ranks[index + 1]}';
  }

  String get trustProgress => '$trustPoints trust points';

  String get achievementsSummary {
    final recognitions = profile['recognitions'];
    if (recognitions is List && recognitions.isNotEmpty) {
      return '${recognitions.length} achievement${recognitions.length == 1 ? '' : 's'} unlocked';
    }
    return 'Achievements unlock as you deliver';
  }

  String text(String key, {String fallback = ''}) {
    final value = '${profile[key] ?? fallback}'.trim();
    return value == 'null' ? '' : value;
  }

  double number(String key, {double fallback = 0}) {
    final value = profile[key];
    return value is num ? value.toDouble() : fallback;
  }

  String whole(String key, {String fallback = '0'}) {
    final value = profile[key] ?? earnings[key];
    if (value is num) return value.toInt().toString();
    final text = '$value'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  String percent(String key, {String? fallbackKey}) {
    final value =
        profile[key] ?? (fallbackKey == null ? null : profile[fallbackKey]);
    if (value is num) {
      final normalized = value <= 1 ? value * 100 : value;
      return '${normalized.round()}%';
    }
    return 'New';
  }

  double moneyValue(String key) {
    final value = earnings[key] ?? profile[key];
    return value is num ? value.toDouble() : 0;
  }

  DateTime? timestamp(String key) => timestampFromAny(profile[key]);
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.data,
    required this.onEditPhoto,
    required this.onEditProfile,
  });

  final _RiderProfileData data;
  final VoidCallback onEditPhoto;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      radius: 30,
      padding: const EdgeInsets.all(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 680;
          final photo = _ProfilePhoto(
            imageUrl: data.photoUrl,
            initials: data.initials,
            onTap: onEditPhoto,
          );
          final text = _HeroText(data: data, onEditProfile: onEditProfile);
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                photo,
                const SizedBox(width: 22),
                Expanded(child: text),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              photo,
              const SizedBox(height: 18),
              text,
            ],
          );
        },
      ),
    );
  }
}

class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({
    required this.imageUrl,
    required this.initials,
    required this.onTap,
  });

  final String imageUrl;
  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Edit profile photo',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [RiderPalette.blue, Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: RiderPalette.blue.withValues(alpha: .22),
                    blurRadius: 34,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: imageUrl.isEmpty
                    ? ColoredBox(
                        color: const Color(0xFF111827),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: RiderPalette.paper,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: RiderPalette.paper,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: RiderPalette.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: RiderPalette.background, width: 3),
                ),
                child: const Icon(Icons.edit_rounded,
                    color: RiderPalette.paper, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText({required this.data, required this.onEditProfile});

  final _RiderProfileData data;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: RiderPalette.paper,
            fontFamily: RiderTypography.heading,
            fontSize: 34,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.handle,
          style: const TextStyle(
            color: RiderPalette.muted,
            fontFamily: RiderTypography.mono,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeroPill(
              icon: Icons.verified_rounded,
              label: data.verifiedLabel,
              color: data.verifiedLabel == 'Verified'
                  ? RiderPalette.green
                  : RiderPalette.amber,
            ),
            _HeroPill(
              icon: Icons.military_tech_rounded,
              label: data.rank,
              color: RiderPalette.blue,
            ),
            _HeroPill(
              icon: Icons.auto_awesome_rounded,
              label: '${data.trustPoints} trust',
              color: RiderPalette.purple,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          data.memberSince,
          style: const TextStyle(color: RiderPalette.muted, fontSize: 13),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: onEditProfile,
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Edit Profile'),
          style: FilledButton.styleFrom(
            backgroundColor: RiderPalette.blue,
            foregroundColor: RiderPalette.paper,
            minimumSize: const Size(150, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data});

  final _RiderProfileData data;

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('Deliveries Completed', data.deliveriesCompleted),
      ('Customer Rating', data.customerRating),
      ('Acceptance Rate', data.acceptanceRate),
      ('On-Time Rate', data.onTimeRate),
      ('Trust Points', '${data.trustPoints}'),
    ];
    return RiderGlassSurface(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final stat in stats)
              SizedBox(
                width: constraints.maxWidth >= 760
                    ? (constraints.maxWidth - 32) / 5
                    : constraints.maxWidth >= 520
                        ? (constraints.maxWidth - 16) / 3
                        : (constraints.maxWidth - 8) / 2,
                child: _StatTile(label: stat.$1, value: stat.$2),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: RiderPalette.paper,
                fontFamily: RiderTypography.mono,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: RiderPalette.muted,
                fontSize: 11.5,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.rows});

  final String title;
  final List<_ProfileRow> rows;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .42),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            RiderGlassSurface(
              radius: 24,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    rows[i],
                    if (i != rows.length - 1) const _ProfileDivider(),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

enum _ProfileRowTone { normal, danger }

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.statusColor,
    this.tone = _ProfileRowTone.normal,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color? statusColor;
  final _ProfileRowTone tone;

  @override
  Widget build(BuildContext context) {
    final color = tone == _ProfileRowTone.danger
        ? RiderPalette.red
        : statusColor ?? RiderPalette.blue;
    return Semantics(
      button: true,
      label: '$title. $description',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 78),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: .18)),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tone == _ProfileRowTone.danger
                              ? RiderPalette.red
                              : RiderPalette.paper,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RiderPalette.muted,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: .42), size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileDivider extends StatelessWidget {
  const _ProfileDivider();

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        indent: 16,
        endIndent: 16,
        color: Colors.white.withValues(alpha: .07),
      );
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: RiderPalette.blue),
      );
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => RiderEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Profile unavailable',
        message: 'We could not load your Rider profile.',
        actionLabel: 'Retry',
        onAction: onRetry,
      );
}

class RiderLegalView extends StatelessWidget {
  const RiderLegalView({super.key, this.initial});

  final String? initial;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: RiderPalette.background,
        appBar: AppBar(
          title: Text(initial ?? 'Legal'),
          backgroundColor: RiderPalette.background,
          foregroundColor: RiderPalette.paper,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              _ProfileSection(
                title: 'Legal',
                rows: [
                  _ProfileRow(
                    icon: Icons.description_outlined,
                    title: 'Terms',
                    description: 'Circum terms of service',
                    onTap: () =>
                        launchUrl(Uri.parse('https://circumuk.com/terms')),
                  ),
                  _ProfileRow(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy',
                    description: 'Privacy policy and data controls',
                    statusColor: RiderPalette.green,
                    onTap: () =>
                        launchUrl(Uri.parse('https://circumuk.com/privacy')),
                  ),
                  _ProfileRow(
                    icon: Icons.assignment_outlined,
                    title: 'Rider Agreement',
                    description: 'Rider operating agreement',
                    statusColor: RiderPalette.amber,
                    onTap: () =>
                        launchUrl(Uri.parse('https://circumuk.com/terms')),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

Future<void> _confirmSignOut(BuildContext context) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: RiderGlassSurface(
          radius: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sign out?',
                style: TextStyle(
                  color: RiderPalette.paper,
                  fontFamily: RiderTypography.heading,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You can sign back in with your Rider account.',
                style: TextStyle(color: RiderPalette.muted),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: RiderPalette.red,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Sign Out'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (confirmed == true && context.mounted) {
    context.read<AuthBloc>().add(SignOut());
  }
}

Future<void> _confirmCloseAccount(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final continueClosure = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: RiderGlassSurface(
          radius: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Close your Circum account?',
                style: TextStyle(
                  color: RiderPalette.paper,
                  fontFamily: RiderTypography.heading,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Closing your account will:\n\n'
                '• permanently remove your Circum account\n'
                '• sign you out on all devices\n'
                '• delete your profile information\n'
                '• remove your saved preferences\n'
                '• cancel future scheduled deliveries or rider availability where applicable\n'
                '• retain records only where required by law (for example completed financial records)\n\n'
                'This action cannot be undone once deletion is complete.',
                style: TextStyle(color: RiderPalette.muted, height: 1.45),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: RiderPalette.red,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Continue'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (continueClosure != true || !context.mounted) return;

  try {
    await _reauthenticateRiderForClosure(context, user);
    if (!context.mounted) return;
    final confirmed = await _showRiderDeleteConfirmation(context);
    if (confirmed != true || !context.mounted) return;
    await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('closeCircumAccount')
        .call({'accountType': 'rider'});
    if (context.mounted) {
      context.read<AuthBloc>().add(SignOut());
    }
  } on FirebaseFunctionsException catch (error) {
    if (context.mounted) {
      _showClosureError(
        context,
        error.message ?? 'Your account could not be closed. Please try again.',
      );
    }
  } on FirebaseAuthException catch (error) {
    if (context.mounted) {
      _showClosureError(
        context,
        error.message ?? 'Please sign in again before closing your account.',
      );
    }
  } catch (_) {
    if (context.mounted) {
      _showClosureError(
        context,
        'Your account could not be closed. Please try again.',
      );
    }
  }
}

Future<void> _reauthenticateRiderForClosure(
  BuildContext context,
  User user,
) async {
  final providers = user.providerData.map((info) => info.providerId).toSet();
  if (providers.contains('password')) {
    final password = await _showRiderPasswordReauth(context);
    if (password == null || password.isEmpty) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
    return;
  }
  if (providers.contains('google.com')) {
    await user.reauthenticateWithProvider(GoogleAuthProvider());
    return;
  }
  if (providers.contains('apple.com')) {
    final provider = OAuthProvider('apple.com')
      ..addScope('email')
      ..addScope('name');
    await user.reauthenticateWithProvider(provider);
    return;
  }
  throw FirebaseAuthException(
    code: 'requires-recent-login',
    message: 'Sign in again with your existing provider before closing.',
  );
}

Future<String?> _showRiderPasswordReauth(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm your password'),
      content: TextField(
        controller: controller,
        obscureText: true,
        autofillHints: const [AutofillHints.password],
        decoration: const InputDecoration(labelText: 'Password'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<bool?> _showRiderDeleteConfirmation(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Type DELETE to confirm.'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Confirmation'),
          onChanged: (_) => setDialogState(() {}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: controller.text == 'DELETE'
                ? () => Navigator.pop(context, true)
                : null,
            child: const Text('Delete my account'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return result;
}

void _showClosureError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void _open(BuildContext context, Widget page) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

DateTime? timestampFromAny(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _money(double value) => '£${value.toStringAsFixed(2)}';

String _prettyStatus(String value) {
  final text = value.trim().replaceAll('_', ' ').replaceAll('-', ' ');
  if (text.isEmpty) return '';
  return text
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) =>
          '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

String _monthYear(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${months[value.month - 1]} ${value.year}';
}

String _shortDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
