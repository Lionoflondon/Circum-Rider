import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../app/authentication/bloc/auth_bloc.dart';
import '../app/onboarding/onboarding.dart';
import 'app/rider_internal_access/rider_internal_access.dart';
import 'app/review/rider_review_fixture_service.dart';
import 'utils/nav/nav_key.dart';

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
    final pages = <Page<void>>[
      // Unknown app state
      if (state.currentState == AppState.unknownSessionState)
        const MaterialPage(child: _RiderBootSurface()),

      // Unauthenticated app state
      if (state.currentState == AppState.unauthenticated)
        const MaterialPage(child: OnboardingView()),

      // Authenticated app state
      if (state.currentState == AppState.authenticated)
        MaterialPage(child: AppNavView(reviewFixture: reviewFixture)),
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
        ({bool internalAccess, Map<String, dynamic>? reviewFixture})>(
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
