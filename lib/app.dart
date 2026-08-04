import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../app/authentication/bloc/auth_bloc.dart';
import '../app/onboarding/onboarding.dart';
import 'app/authentication/view/add_details.dart';
import 'app/authentication/view/application_submitted.dart';
import 'app/rider_account/rider_account_state.dart';
import 'app/rider_account/rider_account_status_view.dart';
import 'app/rider_internal_access/rider_internal_access.dart';
import 'utils/nav/nav_key.dart';

import '../app/authentication/view/index.dart';
import '../app/bottom_nav/view/app_nav.dart';
import 'utils/app_state/index.dart';

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      if (state.currentState == AppState.authenticated) {
        return FutureBuilder<bool>(
            future: RiderInternalAccess.enabled(forceRefresh: true),
            builder: (context, internalAccess) =>
                _buildNavigator(state, internalAccess.data == true));
      }
      return _buildNavigator(state, false);
    });
  }

  Widget _buildNavigator(AuthState state, bool internalAccess) {
    final showOnboarding = state.currentState == AppState.authenticated &&
        !internalAccess &&
        (state.riderAccountState == RiderAccountState.onboardingNotStarted ||
            state.riderAccountState == RiderAccountState.onboardingInProgress);
    final showSubmitted = state.currentState == AppState.authenticated &&
        !internalAccess &&
        (state.riderAccountState == RiderAccountState.submitted ||
            state.riderAccountState == RiderAccountState.pendingReview);
    final showRestricted = state.currentState == AppState.authenticated &&
        !internalAccess &&
        (state.riderAccountState == RiderAccountState.moreInformationRequired ||
            state.riderAccountState == RiderAccountState.rejected ||
            state.riderAccountState == RiderAccountState.suspended ||
            state.riderAccountState == RiderAccountState.frozen ||
            state.riderAccountState == RiderAccountState.closed);
    final showOperational = state.currentState == AppState.authenticated &&
        state.authenticatedStatus == AuthenticatedStatus.authenticated &&
        (internalAccess ||
            state.riderAccountState == RiderAccountState.approved);
    final showAuthenticatedFallback =
        state.currentState == AppState.authenticated &&
            !showOnboarding &&
            !showSubmitted &&
            !showRestricted &&
            !showOperational;

    return Navigator(
      key: NavKey.navKey,
      pages: [
        // Unknown app state
        if (state.currentState == AppState.unknownSessionState)
          const MaterialPage(child: IndexPage()),

        // Unauthenticated app state
        if (state.currentState == AppState.unauthenticated)
          const MaterialPage(
            child: OnboardingView(),
          ),

        if (showOnboarding) const MaterialPage(child: AddDetailsView()),

        if (showSubmitted)
          const MaterialPage(child: ApplicationSubmittedView()),

        if (showRestricted)
          MaterialPage(
            child: RiderAccountStatusView(
              accountState: state.riderAccountState,
            ),
          ),

        // Authenticated app state
        if (showOperational) const MaterialPage(child: AppNavView()),

        // Any authenticated state that has not fully reconciled must still
        // render a recoverable account screen instead of an empty Navigator.
        if (showAuthenticatedFallback)
          MaterialPage(
            child: RiderAccountStatusView(
              accountState: state.riderAccountState,
            ),
          ),
      ],
      onPopPage: (route, result) {
        // route.didPop(result);

        if (!route.didPop(result)) return false;
        return true;
      },
    );
  }
}
