import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../app/authentication/bloc/auth_bloc.dart';
import '../app/onboarding/onboarding.dart';
import 'app/authentication/view/add_details.dart';
import 'app/authentication/view/application_submitted.dart';
import 'app/rider_account/rider_account_state.dart';
import 'app/rider_account/rider_account_status_view.dart';
import 'app/rider_internal_access/rider_internal_access.dart';
import 'app/review/rider_review_fixture_screen.dart';
import 'app/review/rider_review_fixture_service.dart';
import 'utils/nav/nav_key.dart';

import '../app/authentication/view/index.dart';
import '../app/bottom_nav/view/app_nav.dart';
import 'utils/app_state/index.dart';

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state.currentState == AppState.authenticated) {
          return _AuthenticatedStartupGate(state: state);
        }
        return _buildNavigator(state, false);
      },
    );
  }

  Widget _buildNavigator(
    AuthState state,
    bool internalAccess, {
    Map<String, dynamic>? reviewFixture,
    VoidCallback? onRetry,
  }) {
    final hasReviewFixture = reviewFixture != null;
    final pages = <Page<void>>[
      // Unknown app state
      if (state.currentState == AppState.unknownSessionState)
        const MaterialPage(child: IndexPage()),

      // Unauthenticated app state
      if (state.currentState == AppState.unauthenticated)
        const MaterialPage(child: OnboardingView()),

      if (!internalAccess &&
          !hasReviewFixture &&
          state.currentState == AppState.authenticated &&
          (state.riderAccountState == RiderAccountState.onboardingNotStarted ||
              state.riderAccountState ==
                  RiderAccountState.onboardingInProgress))
        const MaterialPage(child: AddDetailsView()),

      if (!internalAccess &&
          !hasReviewFixture &&
          state.currentState == AppState.authenticated &&
          (state.riderAccountState == RiderAccountState.submitted ||
              state.riderAccountState == RiderAccountState.pendingReview))
        const MaterialPage(child: ApplicationSubmittedView()),

      if (!internalAccess &&
          !hasReviewFixture &&
          state.currentState == AppState.authenticated &&
          (state.riderAccountState ==
                  RiderAccountState.moreInformationRequired ||
              state.riderAccountState == RiderAccountState.rejected ||
              state.riderAccountState == RiderAccountState.suspended ||
              state.riderAccountState == RiderAccountState.frozen ||
              state.riderAccountState == RiderAccountState.closed))
        MaterialPage(
          child: RiderAccountStatusView(accountState: state.riderAccountState),
        ),

      // Authenticated app state
      if (!hasReviewFixture &&
          state.currentState == AppState.authenticated &&
          (internalAccess ||
              state.riderAccountState == RiderAccountState.approved))
        const MaterialPage(child: AppNavView()),

      if (state.currentState == AppState.authenticated && hasReviewFixture)
        MaterialPage(child: RiderReviewFixtureScreen(fixture: reviewFixture)),
    ];

    return Navigator(
      key: NavKey.navKey,
      pages: pages.isEmpty
          ? [MaterialPage(child: _RiderBootSurface(onRetry: onRetry))]
          : pages,
      onPopPage: (route, result) {
        // route.didPop(result);

        if (!route.didPop(result)) return false;
        return true;
      },
    );
  }
}

class _AuthenticatedStartupGate extends StatefulWidget {
  const _AuthenticatedStartupGate({required this.state});

  final AuthState state;

  @override
  State<_AuthenticatedStartupGate> createState() =>
      _AuthenticatedStartupGateState();
}

class _AuthenticatedStartupGateState extends State<_AuthenticatedStartupGate> {
  late Future<({bool internalAccess, Map<String, dynamic>? reviewFixture})>
  _startupAccessFuture;

  @override
  void initState() {
    super.initState();
    _startupAccessFuture = _resolveStartupAccess();
  }

  Future<({bool internalAccess, Map<String, dynamic>? reviewFixture})>
  _resolveStartupAccess() async {
    final internalAccess = await RiderInternalAccess.enabled(
      forceRefresh: true,
    ).timeout(const Duration(seconds: 5), onTimeout: () => false);
    Map<String, dynamic>? reviewFixture;
    try {
      reviewFixture = await RiderReviewFixtureService().getOwnFixture().timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {
      // Review access is opt-in and server-authoritative. Any failure falls
      // closed to the Rider's normal account-state route.
    }
    return (internalAccess: internalAccess, reviewFixture: reviewFixture);
  }

  void _retry() {
    setState(() {
      _startupAccessFuture = _resolveStartupAccess();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
      ({bool internalAccess, Map<String, dynamic>? reviewFixture})
    >(
      future: _startupAccessFuture,
      builder: (context, startupAccess) {
        if (startupAccess.connectionState != ConnectionState.done) {
          return App()._buildNavigator(widget.state, false);
        }
        if (startupAccess.hasError) {
          return App()._buildNavigator(widget.state, false, onRetry: _retry);
        }
        final access = startupAccess.data!;
        return App()._buildNavigator(
          widget.state,
          access.internalAccess,
          reviewFixture: access.reviewFixture,
        );
      },
    );
  }
}

class _RiderBootSurface extends StatelessWidget {
  const _RiderBootSurface({this.message = 'Loading Rider…', this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(message, style: const TextStyle(color: Colors.white)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
