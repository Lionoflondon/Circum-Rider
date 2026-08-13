import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bottom_nav/bloc/navbar_bloc.dart';
import '../rider_design/rider_ui.dart';
import 'rider_stripe_return.dart';

class RiderStripeReturnView extends StatefulWidget {
  const RiderStripeReturnView({
    super.key,
    required this.intent,
    required this.onComplete,
  });

  final RiderStripeReturnIntent intent;
  final VoidCallback onComplete;

  @override
  State<RiderStripeReturnView> createState() => _RiderStripeReturnViewState();
}

class _RiderStripeReturnViewState extends State<RiderStripeReturnView> {
  bool _busy = true;
  bool _redirecting = false;
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    _resolveReturn();
  }

  Future<void> _resolveReturn() async {
    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw StateError(
          'Your Rider session could not be restored. Sign in again.',
        );
      }
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      if (widget.intent.isRefresh) {
        final response = await functions
            .httpsCallable('refreshStripeOnboardingLink')
            .call(const <String, dynamic>{});
        final data = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : const <String, dynamic>{};
        final url = Uri.tryParse('${data['url'] ?? ''}');
        if (url == null || url.scheme != 'https' || url.host.trim().isEmpty) {
          throw StateError('Stripe did not return a secure onboarding link.');
        }
        if (mounted) {
          setState(() {
            _busy = false;
            _redirecting = true;
          });
        }
        final opened = await launchUrl(
          url,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_self',
        );
        if (!opened) {
          throw StateError('Stripe onboarding could not be reopened.');
        }
        return;
      }

      final response = await functions
          .httpsCallable('syncStripeConnectStatus')
          .call(const <String, dynamic>{});
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      final status = '${data['stripeStatus'] ?? data['status'] ?? 'received'}'
          .trim()
          .toLowerCase();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = status;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _redirecting = false;
        _error = _message(error);
      });
    }
  }

  void _backToRider() {
    context.read<NavbarBloc>().add(ChangeTabIndex(index: 3));
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final success = !_busy && _error == null && !_redirecting;
    final title = _redirecting
        ? 'Reopening Stripe'
        : _error != null
            ? 'Stripe needs another try'
            : success
                ? _successTitle(_status)
                : 'Checking Stripe Connect';
    final message = _redirecting
        ? 'Keeping you in the Rider payout setup flow.'
        : _error ??
            (success
                ? _successMessage(_status)
                : 'Restoring your authenticated Rider payout status.');

    return Scaffold(
      backgroundColor: RiderPalette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: RiderGlassSurface(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      _error != null
                          ? Icons.error_outline_rounded
                          : success
                              ? Icons.verified_rounded
                              : Icons.sync_rounded,
                      size: 42,
                      color: _error != null
                          ? RiderPalette.red
                          : success
                              ? RiderPalette.green
                              : RiderPalette.blue,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: RiderPalette.paper,
                        fontFamily: RiderTypography.heading,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: RiderPalette.muted,
                        height: 1.5,
                      ),
                    ),
                    if (_busy || _redirecting) ...[
                      const SizedBox(height: 24),
                      const Center(child: CircularProgressIndicator()),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 24),
                      RiderPrimaryButton(
                        label: 'Try again',
                        icon: Icons.refresh_rounded,
                        onPressed: _resolveReturn,
                      ),
                    ],
                    if (!_busy && !_redirecting) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _backToRider,
                        child: const Text('Back to Rider earnings'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _successTitle(String? status) {
    return const {'payouts_enabled', 'ready', 'complete'}.contains(status)
        ? 'Stripe Connect is ready'
        : 'Back inside Circum Rider';
  }

  static String _successMessage(String? status) {
    return const {'payouts_enabled', 'ready', 'complete'}.contains(status)
        ? 'Your payout account is connected. Your current status is available in Rider earnings.'
        : 'Your Stripe details were received. Any remaining payout requirements are shown in Rider earnings.';
  }

  static String _message(Object error) {
    if (error is FirebaseFunctionsException) {
      final value = error.message?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    final value = '$error'.replaceFirst('Bad state: ', '').trim();
    return value.isEmpty ? 'Stripe Connect could not be restored.' : value;
  }
}
