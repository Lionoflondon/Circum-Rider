import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../account/view/earnings.dart';
import '../../rider_design/rider_ui.dart';
import '../../rider_jobs/rider_job_offer_screen.dart';
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

        return RiderMobileFrame(
          child: Scaffold(
            backgroundColor: RiderPalette.background,
            body: IndexedStack(index: nav.currentNavIndex, children: screens),
            bottomNavigationBar: _RiderDashboardNav(
              currentIndex: nav.currentNavIndex,
              onSelect: select,
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
              _CentralAction(onTap: () => onSelect(1)),
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
  const _CentralAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open delivery offers',
      child: GestureDetector(
        onTap: onTap,
        child: Transform.translate(
          offset: const Offset(0, -14),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [RiderPalette.blue, RiderPalette.purple],
              ),
              boxShadow: [
                BoxShadow(
                  color: RiderPalette.blue.withValues(alpha: .42),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
