import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../app/authentication/bloc/auth_bloc.dart';
import '../app/onboarding/onboarding.dart';
import 'app/onboarding/rider_application_centre.dart';
import 'utils/nav/nav_key.dart';
import 'utils/app_state/index.dart';

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      return _buildNavigator(state);
    });
  }

  Widget _buildNavigator(AuthState state) {
    final pages = <Page<void>>[
      // Unknown app state
      if (state.currentState == AppState.unknownSessionState)
        const MaterialPage(child: OnboardingView()),

      // Unauthenticated app state
      if (state.currentState == AppState.unauthenticated)
        const MaterialPage(
          child: OnboardingView(),
        ),

      if (state.currentState == AppState.authenticated)
        const MaterialPage(child: RiderApplicationCentre()),
    ];

    if (pages.isEmpty) {
      pages.add(MaterialPage(
        child: state.currentState == AppState.authenticated
            ? const RiderApplicationCentre()
            : const OnboardingView(),
      ));
    }

    return Navigator(
      key: NavKey.navKey,
      pages: pages,
      onPopPage: (route, result) {
        // route.didPop(result);

        if (!route.didPop(result)) return false;
        return true;
      },
    );
  }
}
