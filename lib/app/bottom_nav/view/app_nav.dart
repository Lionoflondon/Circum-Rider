import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../account/view/earnings.dart';
import '../../home/bloc/home_bloc.dart';
import '../../rider_design/rider_ui.dart';
import '../../rider_jobs/rider_job_offer_screen.dart';
import '../../ratings/rider_appreciation.dart';
import '../../rider_shell/rider_dashboard_view.dart';
import '../../rider_shell/rider_profile_view.dart';
import '../../schedule/rider_schedule_view.dart';
import '../bloc/navbar_bloc.dart';

/// The one canonical authenticated Rider shell.
///
/// Delivery chat, notifications and schedule remain contextual destinations;
/// they are intentionally not restored as legacy primary tabs.
class AppNavView extends StatelessWidget {
  const AppNavView({super.key});

  static const labels = ['Home', 'Jobs', 'Action', 'Earnings', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavbarBloc, NavbarState>(
      builder: (context, nav) {
        void select(int index) =>
            context.read<NavbarBloc>().add(ChangeTabIndex(index: index));

        final screens = <Widget>[
          RiderDashboardView(onSelectTab: select),
          RiderJobOfferScreen(
            onScheduledAccepted: () => select(2),
            onNavigateTab: select,
          ),
          const RiderScheduleView(embedded: true),
          const EarningsView(embedded: true),
          RiderProfileView(onSelectTab: select),
        ];

        return RiderAppreciationListener(
          child: RiderMobileFrame(
            child: Scaffold(
              backgroundColor: RiderPalette.background,
              body: IndexedStack(index: nav.currentNavIndex, children: screens),
              bottomNavigationBar: _RiderDashboardNav(
                currentIndex: nav.currentNavIndex,
                onSelect: select,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RiderDashboardNav extends StatelessWidget {
  const _RiderDashboardNav({
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      radius: 0,
      opacity: .58,
      blur: 18,
      padding: EdgeInsets.zero,
      borderColor: Colors.white.withValues(alpha: .10),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Home',
                selected: currentIndex == 0,
                onTap: () => onSelect(0),
              ),
              _NavItem(
                icon: Icons.work_outline_rounded,
                selectedIcon: Icons.work_rounded,
                label: 'Jobs',
                selected: currentIndex == 1,
                onTap: () => onSelect(1),
              ),
              const _CentralAction(),
              _NavItem(
                icon: Icons.account_balance_wallet_outlined,
                selectedIcon: Icons.account_balance_wallet_rounded,
                label: 'Earnings',
                selected: currentIndex == 3,
                onTap: () => onSelect(3),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: 'Profile',
                selected: currentIndex == 4,
                onTap: () => onSelect(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? RiderPalette.paper : const Color(0xFF5F6779);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 64,
          height: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selectedIcon : icon, color: color, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CentralAction extends StatelessWidget {
  const _CentralAction();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, home) {
        final online = home.rideStatus == RideStatus.online;
        final loading = home.requestStatus == RequestStatus.loading;
        final semantic = online ? 'Rider online. Go offline' : 'Go online';
        return Semantics(
          button: true,
          label: semantic,
          child: GestureDetector(
            onTap: () => _showAvailabilitySheet(context, home),
            child: Transform.translate(
              offset: const Offset(0, -14),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: online
                        ? const [RiderPalette.green, RiderPalette.blue]
                        : const [RiderPalette.blue, RiderPalette.purple],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (online ? RiderPalette.green : RiderPalette.blue)
                          .withValues(alpha: .42),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(15),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        online
                            ? Icons.power_settings_new_rounded
                            : Icons.add_rounded,
                        color: Colors.white,
                        size: online ? 25 : 28,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAvailabilitySheet(BuildContext context, HomeState home) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return BlocProvider.value(
          value: context.read<HomeBloc>(),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: RiderGlassSurface(
                radius: 26,
                blur: 14,
                opacity: .72,
                padding: const EdgeInsets.all(20),
                child: BlocBuilder<HomeBloc, HomeState>(
                  builder: (context, liveHome) {
                    final liveOnline = liveHome.rideStatus == RideStatus.online;
                    final busy =
                        liveHome.requestStatus == RequestStatus.loading;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (liveOnline
                                        ? RiderPalette.green
                                        : RiderPalette.blue)
                                    .withValues(alpha: .14),
                              ),
                              child: Icon(
                                liveOnline
                                    ? Icons.wifi_tethering_rounded
                                    : Icons.power_settings_new_rounded,
                                color: liveOnline
                                    ? RiderPalette.green
                                    : RiderPalette.blue,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    liveOnline ? 'Online' : 'Offline',
                                    style: const TextStyle(
                                      color: RiderPalette.paper,
                                      fontFamily: RiderTypography.heading,
                                      fontSize: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    liveOnline
                                        ? 'Nearby eligible offers can reach you.'
                                        : 'Go online to receive eligible offers.',
                                    style: const TextStyle(
                                      color: RiderPalette.muted,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if ((liveHome.message ?? '').isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            liveHome.message!,
                            style: const TextStyle(
                              color: RiderPalette.amber,
                              fontSize: 12.5,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () {
                                  context.read<HomeBloc>().add(
                                        SetRideStatus(
                                          status: liveOnline
                                              ? RideStatus.offline
                                              : RideStatus.online,
                                        ),
                                      );
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: liveOnline
                                ? Colors.white.withValues(alpha: .10)
                                : RiderPalette.blue,
                            foregroundColor: RiderPalette.paper,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(liveOnline ? 'Go offline' : 'Go online'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Close'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
