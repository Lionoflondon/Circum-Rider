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
/// Delivery chat and notifications remain contextual destinations; they are
/// intentionally not permanent primary tabs.
class AppNavView extends StatelessWidget {
  const AppNavView({super.key});

  static const labels = ['Home', 'Jobs', 'Schedule', 'Earnings', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavbarBloc, NavbarState>(
      builder: (context, nav) {
        void select(int index) =>
            context.read<NavbarBloc>().add(ChangeTabIndex(index: index));

        final screens = <Widget>[
          RiderDashboardView(onSelectTab: select),
          RiderJobOfferScreen(onScheduledAccepted: () => select(2)),
          const RiderScheduleView(embedded: true),
          const EarningsView(embedded: true),
          RiderProfileView(onSelectTab: select),
        ];

        return RiderMobileFrame(
          child: Scaffold(
            backgroundColor: RiderPalette.background,
            body: IndexedStack(index: nav.currentNavIndex, children: screens),
            bottomNavigationBar: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xF20D111C),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(.08)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: NavigationBar(
                  height: 68,
                  selectedIndex: nav.currentNavIndex,
                  onDestinationSelected: select,
                  backgroundColor: Colors.transparent,
                  indicatorColor: RiderPalette.blue.withOpacity(.16),
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: const [
                    NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: 'Home'),
                    NavigationDestination(
                        icon: Icon(Icons.work_outline_rounded),
                        selectedIcon: Icon(Icons.work_rounded),
                        label: 'Jobs'),
                    NavigationDestination(
                        icon: Icon(Icons.calendar_month_outlined),
                        selectedIcon: Icon(Icons.calendar_month_rounded),
                        label: 'Schedule'),
                    NavigationDestination(
                        icon: Icon(Icons.account_balance_wallet_outlined),
                        selectedIcon:
                            Icon(Icons.account_balance_wallet_rounded),
                        label: 'Earnings'),
                    NavigationDestination(
                        icon: Icon(Icons.person_outline_rounded),
                        selectedIcon: Icon(Icons.person_rounded),
                        label: 'Profile'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
