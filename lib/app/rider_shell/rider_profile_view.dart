import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:url_launcher/url_launcher.dart';

import '../account/view/account_details.dart';
import '../authentication/bloc/auth_bloc.dart';
import '../founder_access/founder_rider_access.dart';
import '../history/view/history.dart';
import '../notifications/rider_notifications_view.dart';
import '../onboarding/rider_guide_view.dart';
import '../recognitions/rider_recognitions.dart';
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
        message: 'Sign in to view Rider options.',
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      key: ValueKey('rider-options-profile-$_reload'),
      stream: FirebaseFirestore.instance
          .collection('riderProfiles')
          .doc(user.uid)
          .snapshots(),
      builder: (context, profileSnapshot) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          key: ValueKey('rider-options-rider-$_reload'),
          stream: FirebaseFirestore.instance
              .collection('riders')
              .doc(user.uid)
              .snapshots(),
          builder: (context, riderSnapshot) {
            if (profileSnapshot.hasError || riderSnapshot.hasError) {
              return _OptionsError(
                onRetry: () => setState(() => _reload++),
              );
            }
            if (!profileSnapshot.hasData && !riderSnapshot.hasData) {
              return const _OptionsLoading();
            }
            final rider = riderSnapshot.data?.data() ?? const {};
            final riderProfile = profileSnapshot.data?.data() ?? const {};
            final profile = <String, dynamic>{...rider, ...riderProfile};
            final accountState = RiderAccountStateResolver.resolveRecords(
              rider: rider,
              riderProfile: riderProfile,
            );
            return _OptionsScreen(
              user: user,
              profile: profile,
              accountState: accountState,
              onSelectTab: widget.onSelectTab,
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

  static String accountStatus(RiderAccountState state) {
    final text = RiderAccountStateResolver.storageValue(state);
    return _sentence(text);
  }

  static String verificationStatus(Map<String, dynamic> profile) {
    final state = documentSummary(profile).toLowerCase();
    if (state == 'approved') return 'Verified';
    if (state.contains('review')) return 'Under review';
    if (state.contains('rejected')) return 'Rejected';
    if (state.contains('expired')) return 'Expired';
    if (state.contains('attention') || state.contains('not supplied')) {
      return 'Action required';
    }
    return documentSummary(profile);
  }

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

  static String notificationSummary() => 'Job offers, messages and updates';

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

  static String _sentence(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _OptionsScreen extends StatelessWidget {
  const _OptionsScreen({
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
    final status = _ProfileData.accountStatus(accountState);
    final verificationStatus = _ProfileData.verificationStatus(profile);
    final recognitions = RiderRecognitions.from(profile);

    return CustomScrollView(
      key: const PageStorageKey('rider-options-screen'),
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            sliver: SliverList.list(
              children: [
                const _OptionsTopBar(),
                const SizedBox(height: 12),
                const FounderRiderBadge(),
                const SizedBox(height: 12),
                _IdentityCard(
                  name: name,
                  photo: photo,
                  initials: _ProfileData.initials(name),
                  rank: rank?.rank ?? 'Rank updating',
                  trust: rank == null
                      ? 'Trust updating'
                      : '${rank.trustPoints} Trust',
                  verificationStatus: verificationStatus,
                  accountStatus: status,
                  recognitions: recognitions,
                  onTap: () => _open(context, const AccountDetails()),
                ),
                const SizedBox(height: 24),
                _OptionsSection(
                  label: 'Account',
                  children: [
                    _OptionRow(
                      icon: Icons.person_outline_rounded,
                      iconColor: RiderPalette.blue,
                      title: 'Personal details',
                      subtitle: _personalDetailsSubtitle(user, profile),
                      onTap: () => _open(context, const AccountDetails()),
                    ),
                    _OptionRow(
                      icon: Icons.verified_user_outlined,
                      iconColor: RiderPalette.green,
                      title: 'Documents & verification',
                      subtitle: verificationStatus,
                      onTap: () => _open(context, VerificationView()),
                    ),
                    _OptionRow(
                      icon: Icons.history_rounded,
                      iconColor: RiderPalette.amber,
                      title: 'Delivery activity',
                      subtitle:
                          'Completed, cancelled and historical deliveries',
                      onTap: () => _open(context, const HistoryView()),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _OptionsSection(
                  label: 'Preferences',
                  children: [
                    _PermissionRow(
                      icon: Icons.notifications_none_rounded,
                      iconColor: RiderPalette.purple,
                      title: 'Notifications',
                      summary: _ProfileData.notificationSummary(),
                      permission: permissions.Permission.notification,
                      onTap: () => _open(
                        context,
                        RiderNotificationsView(onNavigateTab: onSelectTab),
                      ),
                    ),
                    _LocationSharingRow(
                      profile: profile,
                      user: user,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _OptionsSection(
                  label: 'Support',
                  children: [
                    _OptionRow(
                      icon: Icons.explore_outlined,
                      iconColor: RiderPalette.blue,
                      title: 'Rider Guide',
                      subtitle: 'Learn how Circum Rider works',
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
                    _OptionRow(
                      icon: Icons.help_outline_rounded,
                      iconColor: RiderPalette.blue,
                      title: 'Support',
                      subtitle: 'Contact Rider Support',
                      onTap: () => _open(context, const SupportView()),
                    ),
                    _OptionRow(
                      icon: Icons.gavel_rounded,
                      iconColor: RiderPalette.muted,
                      title: 'Legal',
                      subtitle: 'Terms, privacy, Rider agreement and licences',
                      onTap: () => _open(context, const RiderLegalView()),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _CloseAccountButton(
                  onTap: () => _confirmCloseAccount(context),
                ),
                const SizedBox(height: 12),
                _SignOutButton(onTap: () => _confirmSignOut(context)),
                const SizedBox(height: 16),
                const _FooterMeta(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _personalDetailsSubtitle(User user, Map<String, dynamic> profile) {
    final phone = '${profile['phoneNumber'] ?? user.phoneNumber ?? ''}'.trim();
    final address =
        '${profile['homeAddress'] ?? profile['address'] ?? ''}'.trim();
    if (phone.isNotEmpty && address.isNotEmpty) return 'Phone and home address';
    if (phone.isNotEmpty) return 'Phone saved · Add home address';
    if (address.isNotEmpty) return 'Home address saved · Add phone';
    return 'Name, phone, home address and account details';
  }
}

class _OptionsTopBar extends StatelessWidget {
  const _OptionsTopBar();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Semantics(
            label: 'Back',
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .045),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .09)),
                ),
                child: const Icon(Icons.chevron_left_rounded,
                    color: RiderPalette.paper),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Options',
            style: TextStyle(
              color: RiderPalette.paper,
              fontFamily: RiderTypography.heading,
              fontSize: 30,
            ),
          ),
        ],
      );
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.name,
    required this.photo,
    required this.initials,
    required this.rank,
    required this.trust,
    required this.verificationStatus,
    required this.accountStatus,
    required this.recognitions,
    required this.onTap,
  });

  final String name;
  final String photo;
  final String initials;
  final String rank;
  final String trust;
  final String verificationStatus;
  final String accountStatus;
  final RiderRecognitions recognitions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Open Rider profile for $name',
        child: _OptionsGlass(
          onTap: onTap,
          borderRadius: 22,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [RiderPalette.blue, Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: RiderPalette.blue.withValues(alpha: .28),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: photo.isEmpty
                    ? Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: photo,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 15),
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
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      verificationStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _statusColor(verificationStatus),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$rank · $trust · $accountStatus',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RiderPalette.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    if (recognitions.hasAny) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (recognitions.foundingRider.awarded)
                            _RecognitionText(
                              label:
                                  'Founding Rider ${recognitions.foundingRider.numberLabel(4)}',
                            ),
                          if (recognitions.legend.awarded)
                            _RecognitionText(
                              label:
                                  'Legend ${recognitions.legend.numberLabel(4)}',
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: RiderPalette.muted),
            ],
          ),
        ),
      );

  Color _statusColor(String status) {
    final value = status.toLowerCase();
    if (value.contains('verified') || value.contains('approved')) {
      return RiderPalette.green;
    }
    if (value.contains('review')) return RiderPalette.amber;
    if (value.contains('rejected') ||
        value.contains('expired') ||
        value.contains('required')) {
      return RiderPalette.red;
    }
    return RiderPalette.muted;
  }
}

class _RecognitionText extends StatelessWidget {
  const _RecognitionText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label.trim(),
        style: const TextStyle(
          color: RiderPalette.blue,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      );
}

class _OptionsSection extends StatelessWidget {
  const _OptionsSection({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: .38),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
          _OptionsGlass(
            padding: EdgeInsets.zero,
            borderRadius: 20,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1) const _HairlineDivider(),
                ],
              ],
            ),
          ),
        ],
      );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
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
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$title. $subtitle',
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                _IconChip(icon: icon, color: iconColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: RiderPalette.paper,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RiderPalette.muted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: RiderPalette.muted),
              ],
            ),
          ),
        ),
      );
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.summary,
    required this.permission,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String summary;
  final permissions.Permission permission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<permissions.PermissionStatus>(
        future: permission.status,
        builder: (context, snapshot) {
          final status = snapshot.hasData
              ? _permissionLabel(snapshot.data!)
              : 'Checking permission';
          return _OptionRow(
            icon: icon,
            iconColor: iconColor,
            title: title,
            subtitle: '$summary · $status',
            onTap: onTap,
          );
        },
      );
}

class _LocationSharingRow extends StatelessWidget {
  const _LocationSharingRow({
    required this.profile,
    required this.user,
  });

  final Map<String, dynamic> profile;
  final User user;

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: Geolocator.isLocationServiceEnabled(),
        builder: (context, snapshot) {
          final service = snapshot.hasData
              ? snapshot.data!
                  ? 'On'
                  : 'Off'
              : 'Checking';
          return _OptionRow(
            icon: Icons.location_searching_rounded,
            iconColor: RiderPalette.blue,
            title: 'Location & GPS',
            subtitle:
                'Used while online and during active deliveries · GPS Services: $service',
            onTap: () => _open(
              context,
              RiderLocationGpsView(profile: profile, user: user),
            ),
          );
        },
      );
}

class RiderLocationGpsView extends StatefulWidget {
  const RiderLocationGpsView({
    super.key,
    required this.profile,
    required this.user,
  });

  final Map<String, dynamic> profile;
  final User user;

  @override
  State<RiderLocationGpsView> createState() => _RiderLocationGpsViewState();
}

class _RiderLocationGpsViewState extends State<RiderLocationGpsView> {
  late Future<_LocationGpsSnapshot> _snapshot;
  String? _gpsTestResult;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _snapshot = _LocationGpsSnapshot.load(widget.user.uid, widget.profile);
  }

  void _refresh() {
    setState(() {
      _snapshot = _LocationGpsSnapshot.load(widget.user.uid, widget.profile);
    });
  }

  Future<void> _runGpsTest() async {
    setState(() {
      _testing = true;
      _gpsTestResult = null;
    });
    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) {
        setState(() {
          _gpsTestResult =
              'Location services are off. Turn on GPS in device settings and try again.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        setState(() {
          _gpsTestResult =
              'Location permission is denied. Allow location for Circum Rider to enable live tracking.';
        });
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _gpsTestResult =
              'Location permission is permanently denied. Open device settings and allow location access.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 12),
      );
      if (position.accuracy > 80) {
        setState(() {
          _gpsTestResult =
              'GPS is available, but accuracy is reduced. Move near a window or outdoors and try again.';
        });
        return;
      }

      setState(() {
        _gpsTestResult = '✓ GPS working correctly';
      });
      _refresh();
    } catch (_) {
      setState(() {
        _gpsTestResult =
            'GPS test could not complete. Check signal, permissions and device location settings, then retry.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _testing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RiderPalette.background,
      body: SafeArea(
        child: FutureBuilder<_LocationGpsSnapshot>(
          future: _snapshot,
          builder: (context, snapshot) {
            final data = snapshot.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Row(
                  children: [
                    _RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      label: 'Back',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Location & GPS',
                        style: TextStyle(
                          color: RiderPalette.paper,
                          fontFamily: RiderTypography.heading,
                          fontSize: 28,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  "Used while you're online, travelling to pickup, navigating to deliveries and completing active deliveries. GPS enables accurate live tracking, ETAs and delivery verification. Location tracking stops automatically when you go offline or complete your final active delivery.",
                  style: TextStyle(
                    color: RiderPalette.muted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    data == null)
                  const _OptionsGlass(
                    child: Text(
                      'Checking GPS status...',
                      style: TextStyle(color: RiderPalette.muted),
                    ),
                  )
                else if (snapshot.hasError)
                  _OptionsGlass(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GPS status unavailable',
                          style: TextStyle(
                            color: RiderPalette.paper,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Check your connection and try again.',
                          style: TextStyle(color: RiderPalette.muted),
                        ),
                        const SizedBox(height: 14),
                        _PrimaryGpsButton(
                          label: 'Retry',
                          onTap: _refresh,
                        ),
                      ],
                    ),
                  )
                else ...[
                  _LocationStatusPanel(snapshot: data!),
                  const SizedBox(height: 14),
                  _GpsTestPanel(
                    testing: _testing,
                    result: _gpsTestResult,
                    onRun: _runGpsTest,
                  ),
                  const SizedBox(height: 14),
                  const _PrivacyPanel(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LocationGpsSnapshot {
  const _LocationGpsSnapshot({
    required this.servicesEnabled,
    required this.permission,
    required this.backgroundEnabled,
    required this.liveTrackingActive,
    required this.accuracyLabel,
    required this.lastUpdateLabel,
  });

  final bool servicesEnabled;
  final LocationPermission permission;
  final bool backgroundEnabled;
  final bool liveTrackingActive;
  final String accuracyLabel;
  final String lastUpdateLabel;

  static Future<_LocationGpsSnapshot> load(
    String riderId,
    Map<String, dynamic> profile,
  ) async {
    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    Position? lastPosition;
    if (servicesEnabled &&
        permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever) {
      lastPosition = await Geolocator.getLastKnownPosition();
    }
    final activeDelivery = await _activeDeliveryFor(riderId, profile);
    final online = _isOnline(profile);
    final liveTrackingActive = online && activeDelivery;

    return _LocationGpsSnapshot(
      servicesEnabled: servicesEnabled,
      permission: permission,
      backgroundEnabled: !kIsWeb && permission == LocationPermission.always,
      liveTrackingActive: liveTrackingActive,
      accuracyLabel: _accuracyLabel(lastPosition),
      lastUpdateLabel: _lastUpdateLabel(lastPosition?.timestamp),
    );
  }

  static bool _isOnline(Map<String, dynamic> profile) {
    final raw = '${profile['availability'] ?? profile['status'] ?? ''}'
        .toLowerCase()
        .trim();
    return raw == 'online' ||
        raw == 'available' ||
        profile['isOnline'] == true ||
        profile['online'] == true;
  }

  static Future<bool> _activeDeliveryFor(
    String riderId,
    Map<String, dynamic> profile,
  ) async {
    final activeDeliveryId =
        '${profile['activeDelivery'] ?? profile['activeDeliveryId'] ?? ''}'
            .trim();
    if (activeDeliveryId.isNotEmpty && activeDeliveryId != 'null') {
      final doc = await FirebaseFirestore.instance
          .collection('deliveryRequests')
          .doc(activeDeliveryId)
          .get();
      return _isActiveDelivery(doc.data());
    }

    final query = await FirebaseFirestore.instance
        .collection('deliveryRequests')
        .where('riderId', isEqualTo: riderId)
        .limit(5)
        .get();
    return query.docs.any((doc) => _isActiveDelivery(doc.data()));
  }

  static bool _isActiveDelivery(Map<String, dynamic>? data) {
    if (data == null) return false;
    final status =
        '${data['deliveryStage'] ?? data['deliveryStatus'] ?? data['status'] ?? ''}'
            .toLowerCase()
            .trim();
    return {
      'accepted',
      'navigating_to_pickup',
      'travelling_to_pickup',
      'approaching_pickup',
      'arrived_at_pickup',
      'waiting_at_pickup',
      'pickup_verification',
      'pickup_verified',
      'collected',
      'in_transit',
      'navigating_to_dropoff',
      'travelling_to_dropoff',
      'approaching_dropoff',
      'arrived_at_dropoff',
      'pin_required',
      'awaiting_pin',
    }.contains(status);
  }
}

class _LocationStatusPanel extends StatelessWidget {
  const _LocationStatusPanel({required this.snapshot});

  final _LocationGpsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final gpsLabel = snapshot.servicesEnabled ? 'On' : 'Off';
    final gpsColor =
        snapshot.servicesEnabled ? RiderPalette.green : RiderPalette.red;
    return _OptionsGlass(
      child: Column(
        children: [
          _StatusLine(
            title: 'GPS Services',
            value: gpsLabel,
            color: gpsColor,
            action: const _PrimaryGpsButton(
              label: 'Open Device Settings',
              onTap: Geolocator.openLocationSettings,
            ),
          ),
          const _HairlineDivider(),
          _StatusLine(
            title: 'Location Permission',
            value: _locationPermissionDetail(snapshot.permission),
            color: _permissionColor(snapshot.permission),
            action: _permissionAction(snapshot.permission),
          ),
          const _HairlineDivider(),
          _StatusLine(
            title: 'Background Location',
            value: snapshot.backgroundEnabled ? 'Enabled' : 'Disabled',
            color: snapshot.backgroundEnabled
                ? RiderPalette.green
                : RiderPalette.amber,
            description:
                'Required to continue live tracking during active deliveries while the app is running in the background.',
          ),
          const _HairlineDivider(),
          _StatusLine(
            title: 'Live Tracking',
            value: snapshot.liveTrackingActive ? 'Active' : 'Inactive',
            color: snapshot.liveTrackingActive
                ? RiderPalette.green
                : RiderPalette.muted,
          ),
          const _HairlineDivider(),
          _StatusLine(
            title: 'GPS Accuracy',
            value: snapshot.accuracyLabel,
            color: _accuracyColor(snapshot.accuracyLabel),
          ),
          const _HairlineDivider(),
          _StatusLine(
            title: 'Last GPS Update',
            value: snapshot.lastUpdateLabel,
            color: RiderPalette.blue,
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.title,
    required this.value,
    required this.color,
    this.description,
    this.action,
  });

  final String title;
  final String value;
  final Color color;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title. $value${description == null ? '' : '. $description'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: RiderPalette.paper,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                style: const TextStyle(
                  color: RiderPalette.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 12),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _GpsTestPanel extends StatelessWidget {
  const _GpsTestPanel({
    required this.testing,
    required this.result,
    required this.onRun,
  });

  final bool testing;
  final String? result;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    return _OptionsGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Run GPS Test',
            style: TextStyle(
              color: RiderPalette.paper,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Checks GPS availability, permission and accuracy for live delivery tracking.',
            style: TextStyle(color: RiderPalette.muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          _PrimaryGpsButton(
            label: testing ? 'Testing GPS...' : 'Run GPS Test',
            onTap: testing ? null : onRun,
          ),
          if (result != null) ...[
            const SizedBox(height: 12),
            Text(
              result!,
              style: TextStyle(
                color: result!.startsWith('✓')
                    ? RiderPalette.green
                    : RiderPalette.amber,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrivacyPanel extends StatelessWidget {
  const _PrivacyPanel();

  @override
  Widget build(BuildContext context) {
    const bullets = [
      'Circum only tracks your location while you\'re online or completing an active delivery.',
      'Tracking automatically stops when you go offline.',
      'Background tracking is only used to maintain accurate delivery progress.',
      'Your live location is never shared publicly.',
      'Only authorised delivery participants and Circum operations can view active delivery locations.',
    ];
    return _OptionsGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Privacy',
            style: TextStyle(
              color: RiderPalette.paper,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '• $item',
                style: const TextStyle(
                  color: RiderPalette.muted,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrimaryGpsButton extends StatelessWidget {
  const _PrimaryGpsButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: RiderPalette.blue,
            disabledBackgroundColor: RiderPalette.muted.withValues(alpha: .18),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .045),
              border: Border.all(color: Colors.white.withValues(alpha: .09)),
            ),
            child: Icon(icon, color: RiderPalette.paper, size: 20),
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: color, size: 19),
      );
}

class _OptionsGlass extends StatelessWidget {
  const _OptionsGlass({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0D111C).withValues(alpha: .78),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: .09)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .28),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: RiderPalette.blue.withValues(alpha: .06),
                blurRadius: 24,
                offset: const Offset(0, -2),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: .045),
                Colors.white.withValues(alpha: .012),
              ],
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Sign out',
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RiderPalette.red.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: RiderPalette.red.withValues(alpha: .28)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: RiderPalette.red, size: 18),
                SizedBox(width: 10),
                Text(
                  'Sign out',
                  style: TextStyle(
                    color: RiderPalette.red,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _CloseAccountButton extends StatelessWidget {
  const _CloseAccountButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Close Account',
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RiderPalette.red.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: RiderPalette.red.withValues(alpha: .28)),
            ),
            child: const Row(
              children: [
                Icon(Icons.delete_forever_outlined,
                    color: RiderPalette.red, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Close Account',
                        style: TextStyle(
                          color: RiderPalette.red,
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Permanently delete your Circum account and personal data.',
                        style: TextStyle(
                          color: RiderPalette.muted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _FooterMeta extends StatelessWidget {
  const _FooterMeta();

  @override
  Widget build(BuildContext context) => const Column(
        children: [
          Text(
            'CIRCUM RIDER',
            style: TextStyle(
              color: RiderPalette.muted,
              fontFamily: RiderTypography.mono,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'circumuk.com',
            style: TextStyle(
              color: RiderPalette.muted,
              fontFamily: RiderTypography.mono,
              fontSize: 11,
            ),
          ),
        ],
      );
}

class _HairlineDivider extends StatelessWidget {
  const _HairlineDivider();

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        indent: 16,
        endIndent: 16,
        color: Colors.white.withValues(alpha: .07),
      );
}

class _OptionsLoading extends StatelessWidget {
  const _OptionsLoading();

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: RiderPalette.blue),
      );
}

class _OptionsError extends StatelessWidget {
  const _OptionsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => RiderEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Options unavailable',
        message: 'We could not load your Rider account details.',
        actionLabel: 'Retry',
        onAction: onRetry,
      );
}

class RiderLegalView extends StatelessWidget {
  const RiderLegalView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: RiderPalette.background,
        appBar: AppBar(
          title: const Text('Legal'),
          backgroundColor: RiderPalette.background,
          foregroundColor: RiderPalette.paper,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _OptionsSection(
                label: 'Legal',
                children: [
                  _OptionRow(
                    icon: Icons.description_outlined,
                    iconColor: RiderPalette.blue,
                    title: 'Terms',
                    subtitle: 'Circum terms of service',
                    onTap: () =>
                        launchUrl(Uri.parse('https://circumuk.com/terms')),
                  ),
                  _OptionRow(
                    icon: Icons.privacy_tip_outlined,
                    iconColor: RiderPalette.green,
                    title: 'Privacy',
                    subtitle: 'Privacy policy and data controls',
                    onTap: () =>
                        launchUrl(Uri.parse('https://circumuk.com/privacy')),
                  ),
                  _OptionRow(
                    icon: Icons.assignment_outlined,
                    iconColor: RiderPalette.amber,
                    title: 'Rider agreement',
                    subtitle: 'Rider operating agreement',
                    onTap: () =>
                        launchUrl(Uri.parse('https://circumuk.com/terms')),
                  ),
                  _OptionRow(
                    icon: Icons.info_outline_rounded,
                    iconColor: RiderPalette.muted,
                    title: 'Licences and notices',
                    subtitle: 'Third-party licences and app notices',
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Circum Rider',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

String _permissionLabel(permissions.PermissionStatus status) {
  if (status.isGranted) return 'Allowed';
  if (status.isLimited) return 'Limited';
  if (status.isPermanentlyDenied) return 'Open settings';
  if (status.isDenied) return 'Denied';
  if (status.isRestricted) return 'Restricted';
  return 'Not requested';
}

String _locationPermissionDetail(LocationPermission permission) {
  return switch (permission) {
    LocationPermission.always => 'Always Allowed',
    LocationPermission.whileInUse => 'While Using App',
    LocationPermission.denied => 'Denied',
    LocationPermission.deniedForever => 'Denied',
    LocationPermission.unableToDetermine => 'Restricted',
  };
}

Color _permissionColor(LocationPermission permission) {
  return switch (permission) {
    LocationPermission.always => RiderPalette.green,
    LocationPermission.whileInUse => RiderPalette.amber,
    LocationPermission.denied ||
    LocationPermission.deniedForever =>
      RiderPalette.red,
    LocationPermission.unableToDetermine => RiderPalette.amber,
  };
}

Widget? _permissionAction(LocationPermission permission) {
  if (permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse) {
    return null;
  }
  return const _PrimaryGpsButton(
    label: 'Open Device Settings',
    onTap: Geolocator.openAppSettings,
  );
}

String _accuracyLabel(Position? position) {
  if (position == null) return 'Reduced';
  if (position.accuracy <= 25) return 'High';
  if (position.accuracy <= 80) return 'Medium';
  return 'Reduced';
}

Color _accuracyColor(String label) {
  return switch (label) {
    'High' => RiderPalette.green,
    'Medium' => RiderPalette.amber,
    _ => RiderPalette.red,
  };
}

String _lastUpdateLabel(DateTime? timestamp) {
  if (timestamp == null) return 'Unavailable';
  final elapsed = DateTime.now().difference(timestamp).abs();
  if (elapsed.inSeconds < 10) return 'Just now';
  if (elapsed.inMinutes < 1) return '${elapsed.inSeconds} seconds ago';
  if (elapsed.inMinutes == 1) return '1 minute ago';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} minutes ago';
  if (elapsed.inHours == 1) return '1 hour ago';
  return '${elapsed.inHours} hours ago';
}

Future<void> _confirmSignOut(BuildContext context) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _OptionsGlass(
          borderRadius: 24,
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
                child: const Text('Sign out'),
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
        child: _OptionsGlass(
          borderRadius: 24,
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
          error.message ??
              'Your account could not be closed. Please try again.');
    }
  } on FirebaseAuthException catch (error) {
    if (context.mounted) {
      _showClosureError(context,
          error.message ?? 'Please sign in again before closing your account.');
    }
  } catch (_) {
    if (context.mounted) {
      _showClosureError(
          context, 'Your account could not be closed. Please try again.');
    }
  }
}

Future<void> _reauthenticateRiderForClosure(
    BuildContext context, User user) async {
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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

void _open(BuildContext context, Widget page) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}
