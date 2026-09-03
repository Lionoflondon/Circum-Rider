import 'package:flutter/material.dart';

import '../rider_design/rider_ui.dart';
import 'rider_stripe_connect_service.dart';

class RiderPayoutAccountView extends StatefulWidget {
  const RiderPayoutAccountView({super.key, this.service});

  final RiderStripeConnectService? service;

  @override
  State<RiderPayoutAccountView> createState() => _RiderPayoutAccountViewState();
}

class _RiderPayoutAccountViewState extends State<RiderPayoutAccountView>
    with WidgetsBindingObserver {
  late final RiderStripeConnectService _service;
  Map<String, dynamic>? _status;
  String? _error;
  bool _busy = false;
  bool _openedStripe = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? RiderStripeConnectService();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _openedStripe) {
      _openedStripe = false;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await _service.refresh();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Payout status could not be refreshed. Check your connection and retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openStripe() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.openAccount();
      _openedStripe = true;
    } on RiderStripeConnectFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = '${_status?['stripeStatus'] ?? 'not_started'}';
    final ready = _status?['stripePayoutsEnabled'] == true ||
        _status?['payoutsEnabled'] == true;
    return Scaffold(
      backgroundColor: RiderPalette.background,
      appBar: AppBar(
        backgroundColor: RiderPalette.background,
        foregroundColor: RiderPalette.paper,
        title: const Text('Payout Account'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              ready ? 'Stripe Connect ready' : _label(status),
              style: const TextStyle(
                color: RiderPalette.paper,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              ready
                  ? 'Manage your payout details securely with Stripe.'
                  : 'Complete or resume your secure Stripe payout setup.',
              style: const TextStyle(color: RiderPalette.muted, height: 1.5),
            ),
            if (_error != null) ...[
              const SizedBox(height: 18),
              Text(_error!, style: const TextStyle(color: RiderPalette.red)),
            ],
            const SizedBox(height: 24),
            RiderPrimaryButton(
              label: ready ? 'Manage payout account' : 'Continue with Stripe',
              icon: Icons.open_in_new_rounded,
              busy: _busy,
              onPressed: _busy ? null : _openStripe,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh status'),
            ),
          ],
        ),
      ),
    );
  }

  static String _label(String status) => switch (status.toLowerCase()) {
        'action_required' ||
        'restricted' ||
        'disabled' =>
          'Payout account needs attention',
        'onboarding' || 'connected' => 'Payout setup in progress',
        _ => 'Set up your payout account',
      };
}
