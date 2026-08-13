import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../app/authentication/bloc/auth_bloc.dart';
import '../app/onboarding/onboarding.dart';
import 'app/authentication/view/add_details.dart';
import 'app/authentication/view/application_submitted.dart';
import 'app/rider_account/rider_account_state.dart';
import 'app/rider_account/rider_account_status_view.dart';
import 'app/rider_internal_access/rider_internal_access.dart';
import 'app/stripe/rider_stripe_return.dart';
import 'app/stripe/rider_stripe_return_view.dart';
import 'utils/nav/nav_key.dart';

import '../app/authentication/view/index.dart';
import '../app/bottom_nav/view/app_nav.dart';
import 'utils/app_state/index.dart';

class App extends StatelessWidget {
  const App({super.key, this.stripeReturnIntent, this.onStripeReturnComplete});

  final RiderStripeReturnIntent? stripeReturnIntent;
  final VoidCallback? onStripeReturnComplete;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state.currentState == AppState.authenticated) {
          return FutureBuilder<bool>(
            future: RiderInternalAccess.enabled(forceRefresh: true),
            builder: (context, internalAccess) =>
                _buildNavigator(state, internalAccess.data == true),
          );
        }
        return _buildNavigator(state, false);
      },
    );
  }

  Widget _buildNavigator(AuthState state, bool internalAccess) {
    return Navigator(
      key: NavKey.navKey,
      pages: [
        // Unknown app state
        if (state.currentState == AppState.unknownSessionState)
          const MaterialPage(child: IndexPage()),

        // Unauthenticated app state
        if (state.currentState == AppState.unauthenticated)
          const MaterialPage(child: OnboardingView()),

        if (!internalAccess &&
            state.currentState == AppState.authenticated &&
            (state.riderAccountState ==
                    RiderAccountState.onboardingNotStarted ||
                state.riderAccountState ==
                    RiderAccountState.onboardingInProgress))
          const MaterialPage(child: AddDetailsView()),

        if (!internalAccess &&
            state.currentState == AppState.authenticated &&
            (state.riderAccountState == RiderAccountState.submitted ||
                state.riderAccountState == RiderAccountState.pendingReview))
          const MaterialPage(child: ApplicationSubmittedView()),

        if (!internalAccess &&
            state.currentState == AppState.authenticated &&
            (state.riderAccountState ==
                    RiderAccountState.moreInformationRequired ||
                state.riderAccountState == RiderAccountState.rejected ||
                state.riderAccountState == RiderAccountState.suspended ||
                state.riderAccountState == RiderAccountState.frozen ||
                state.riderAccountState == RiderAccountState.closed))
          MaterialPage(
            child: RiderAccountStatusView(
              accountState: state.riderAccountState,
            ),
          ),

        // Authenticated app state
        if (state.currentState == AppState.authenticated &&
            (internalAccess ||
                (state.authenticatedStatus ==
                        AuthenticatedStatus.authenticated &&
                    state.riderAccountState == RiderAccountState.approved)))
          const MaterialPage(child: AppNavView()),

        // Stripe restores only after Firebase Auth has restored the Rider.
        // The underlying account-state page remains in the stack, so closing
        // this result returns to the correct authenticated Rider surface.
        if (state.currentState == AppState.authenticated &&
            stripeReturnIntent != null)
          MaterialPage(
            key: ValueKey(stripeReturnIntent!.canonicalPath),
            child: RiderStripeReturnView(
              intent: stripeReturnIntent!,
              onComplete: onStripeReturnComplete ?? () {},
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
