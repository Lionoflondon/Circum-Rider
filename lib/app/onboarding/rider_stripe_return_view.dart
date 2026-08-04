import 'package:flutter/material.dart';

import '../rider_design/rider_ui.dart';
import 'rider_stripe_payout_onboarding.dart';

class RiderStripeReturnView extends StatefulWidget {
  const RiderStripeReturnView({
    super.key,
    required this.onContinue,
    this.refreshExpiredSession = false,
  });

  final VoidCallback onContinue;
  final bool refreshExpiredSession;

  @override
  State<RiderStripeReturnView> createState() => _RiderStripeReturnViewState();
}

class _RiderStripeReturnViewState extends State<RiderStripeReturnView> {
  final _stripePayouts = const RiderStripePayoutOnboarding();
  String _title = 'Checking payout setup';
  String _message = 'We are updating your payout status.';
  bool _busy = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _completeReturn();
  }

  Future<void> _completeReturn() async {
    setState(() {
      _busy = true;
      _failed = false;
      _title = widget.refreshExpiredSession
          ? 'Refreshing payout setup'
          : 'Checking payout setup';
      _message = widget.refreshExpiredSession
          ? 'We are opening a fresh secure payout setup session.'
          : 'We are updating your payout status.';
    });
    try {
      if (widget.refreshExpiredSession) {
        await _stripePayouts.openPayoutSetup(resume: true);
        if (!mounted) return;
        setState(() {
          _title = 'Action required';
          _message =
              'Stripe needs additional information before your payouts can be enabled.';
          _busy = false;
        });
        return;
      }
      final data = await _stripePayouts.syncPayoutStatus();
      final readiness = riderPayoutReadinessFrom(data);
      if (!mounted) return;
      setState(() {
        _title = riderPayoutReadinessLabel(readiness);
        _message = riderPayoutReadinessBody(readiness);
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _title = 'Payout setup needs attention';
        _message = 'We could not update your payout status. Try again.';
        _busy = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RiderMobileFrame(
      child: Scaffold(
        backgroundColor: RiderPalette.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: RiderGlassSurface(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _failed
                          ? Icons.error_outline_rounded
                          : Icons.account_balance_wallet_outlined,
                      color: _failed ? RiderPalette.amber : RiderPalette.blue,
                      size: 42,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: RiderPalette.paper,
                        fontFamily: RiderTypography.heading,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: RiderPalette.muted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    RiderPrimaryButton(
                      label: _busy ? 'Checking' : 'Continue to Rider',
                      icon: _busy
                          ? Icons.sync_rounded
                          : Icons.arrow_forward_rounded,
                      busy: _busy,
                      onPressed: _busy ? null : widget.onContinue,
                    ),
                    if (_failed) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _completeReturn,
                        child: const Text('Try again'),
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
}
