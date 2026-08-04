import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import '../../rider_design/rider_ui.dart';
import '../../onboarding/rider_stripe_payout_onboarding.dart';
import '../bloc/account_bloc.dart';

class EarningsView extends StatefulWidget {
  const EarningsView({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<EarningsView> createState() => _EarningsViewState();
}

class _EarningsViewState extends State<EarningsView> {
  late Future<Map<String, dynamic>> _summary;
  final _stripePayouts = const RiderStripePayoutOnboarding();
  bool _openingPayoutSetup = false;

  @override
  void initState() {
    super.initState();
    _summary = _loadSummary();
    context.read<AccountBloc>()
      ..add(GetEarnings())
      ..add(GetRequests());
  }

  Future<Map<String, dynamic>> _loadSummary() async {
    final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('getRiderEarningsSummary')
        .call();
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> _openPayoutSetup({required bool resume}) async {
    setState(() => _openingPayoutSetup = true);
    try {
      await _stripePayouts.openPayoutSetup(resume: resume);
      if (mounted) setState(() => _summary = _loadSummary());
    } finally {
      if (mounted) setState(() => _openingPayoutSetup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const RiderEmptyState(
        icon: Icons.lock_outline,
        title: 'Sign in required',
        message: 'Sign in to view Rider earnings.',
      );
    }

    final content = FutureBuilder<Map<String, dynamic>>(
      future: _summary,
      builder: (context, summarySnapshot) {
        if (summarySnapshot.hasError) {
          return _EarningsFailure(
            onRetry: () => setState(() => _summary = _loadSummary()),
          );
        }
        if (!summarySnapshot.hasData) return const _EarningsLoading();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('riderEarnings')
              .doc(uid)
              .snapshots(),
          builder: (context, earningsSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('payoutRequests')
                  .where('riderId', isEqualTo: uid)
                  .limit(30)
                  .snapshots(),
              builder: (context, payoutSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('riderWalletTransactions')
                      .where('riderId', isEqualTo: uid)
                      .limit(40)
                      .snapshots(),
                  builder: (context, transactionSnapshot) {
                    if (earningsSnapshot.hasError ||
                        payoutSnapshot.hasError ||
                        transactionSnapshot.hasError) {
                      return _EarningsFailure(
                        onRetry: () =>
                            setState(() => _summary = _loadSummary()),
                      );
                    }
                    if (!earningsSnapshot.hasData ||
                        !payoutSnapshot.hasData ||
                        !transactionSnapshot.hasData) {
                      return const _EarningsLoading();
                    }

                    final payouts = payoutSnapshot.data?.docs
                            .map((doc) => {'id': doc.id, ...doc.data()})
                            .toList() ??
                        const <Map<String, dynamic>>[];
                    final transactions = transactionSnapshot.data?.docs
                            .map((doc) => {'id': doc.id, ...doc.data()})
                            .toList() ??
                        const <Map<String, dynamic>>[];

                    return _EarningsContent(
                      summary: summarySnapshot.data!,
                      storedEarnings: earningsSnapshot.data?.data() ?? const {},
                      payouts: payouts,
                      transactions: transactions,
                      onRefresh: () =>
                          setState(() => _summary = _loadSummary()),
                      openingPayoutSetup: _openingPayoutSetup,
                      onOpenPayoutSetup: _openPayoutSetup,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );

    if (widget.embedded) {
      return SafeArea(bottom: false, child: content);
    }
    return Scaffold(
      backgroundColor: RiderPalette.background,
      body: SafeArea(bottom: false, child: content),
    );
  }
}

class _EarningsContent extends StatelessWidget {
  const _EarningsContent({
    required this.summary,
    required this.storedEarnings,
    required this.payouts,
    required this.transactions,
    required this.onRefresh,
    required this.openingPayoutSetup,
    required this.onOpenPayoutSetup,
  });

  final Map<String, dynamic> summary;
  final Map<String, dynamic> storedEarnings;
  final List<Map<String, dynamic>> payouts;
  final List<Map<String, dynamic>> transactions;
  final VoidCallback onRefresh;
  final bool openingPayoutSetup;
  final Future<void> Function({required bool resume}) onOpenPayoutSetup;

  @override
  Widget build(BuildContext context) {
    final totals = _map(summary['totals']);
    final available = _number(summary['storedAvailable'] ??
        summary['available'] ??
        summary['availableBalance'] ??
        storedEarnings['availableBalance']);
    final pending = _number(summary['pending'] ??
        summary['pendingBalance'] ??
        storedEarnings['pendingBalance']);
    final processing = _number(summary['processing'] ??
        summary['processingBalance'] ??
        summary['processingPayouts']);
    final lifetime = _number(summary['lifetimeEarnings'] ??
        summary['totalLifetimeEarnings'] ??
        storedEarnings['lifetimeEarnings'] ??
        storedEarnings['totalAmountEarned']);
    final delivery = _number(totals['delivery_earning']);
    final tips = _number(totals['tip']);
    final waiting =
        _number(totals['waiting_fee']) + _number(totals['no_show_fee']);
    final adjustments = _number(totals['adjustment_credit']) -
        _number(totals['adjustment_debit']);
    final unexplained = _number(summary['unexplained']);
    final reconciled = summary['reconciled'] == true;
    final readiness = '${summary['connectReadiness'] ?? 'setup_required'}';
    final payoutReadiness = riderPayoutReadinessFrom(summary);
    final payoutsEnabled =
        payoutReadiness == RiderPayoutReadiness.payoutsEnabled;
    final sortedPayouts = [...payouts]
      ..sort((a, b) => _millis(b).compareTo(_millis(a)));
    final withdrawn = sortedPayouts
        .where(_isPaidPayout)
        .fold<double>(0, (total, item) => total + _payoutAmount(item));
    final explained = delivery + tips + waiting + adjustments;
    final settlement = available - explained;
    final activePayout = _firstWhereOrNull(sortedPayouts, _isActivePayout);
    final pendingPayout = activePayout != null;
    final sortedTransactions = [...transactions]
      ..sort((a, b) => _millis(b).compareTo(_millis(a)));
    final hasEarnings = [
          available,
          pending,
          delivery,
          tips,
          waiting,
          adjustments,
        ].any((value) => value.abs() > 0.009) ||
        sortedPayouts.isNotEmpty ||
        sortedTransactions.isNotEmpty;

    return BlocBuilder<AccountBloc, AccountState>(
      builder: (context, account) => RefreshIndicator(
        color: RiderPalette.blue,
        onRefresh: () async => onRefresh(),
        child: ListView(
          key: const PageStorageKey('rider-earnings-replacement'),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            const _TopBar(),
            const SizedBox(height: 18),
            if (!payoutsEnabled) ...[
              _PayoutSetupBanner(
                readiness: payoutReadiness,
                busy: openingPayoutSetup,
                onPressed: riderPayoutCanContinue(payoutReadiness)
                    ? () => onOpenPayoutSetup(
                          resume: payoutReadiness !=
                              RiderPayoutReadiness.setupRequired,
                        )
                    : null,
              ),
              const SizedBox(height: 18),
            ],
            if (!hasEarnings) ...[
              const _NoEarningsState(),
            ] else ...[
              _BalanceHero(
                available: available,
                readiness: readiness,
                reconciled: reconciled,
                unexplained: unexplained,
                activePayout: activePayout,
                busy: account.status == AccountStatus.loading,
                onWithdraw: pendingPayout ||
                        available <= 0 ||
                        readiness != 'ready' ||
                        !reconciled
                    ? null
                    : () => _requestWithdrawal(context, available),
                payouts: sortedPayouts,
                reviewRequired: _requiresPayoutReview(summary, activePayout),
                reviewMessage:
                    _reviewMessage(summary, activePayout, unexplained),
              ),
              const SizedBox(height: 24),
              _SummaryMetricGrid(
                available: available,
                pending: pending,
                processing: processing,
                lifetime: lifetime,
              ),
              const SizedBox(height: 24),
              _BreakdownGrid(
                delivery: delivery,
                tips: tips,
                waiting: waiting,
                adjustments: adjustments,
                withdrawn: withdrawn,
                settlement: settlement,
              ),
              const SizedBox(height: 24),
              _PerformanceSection(
                summary: summary,
                storedEarnings: storedEarnings,
                transactions: sortedTransactions,
              ),
              const SizedBox(height: 24),
              _AnalyticsSection(transactions: sortedTransactions),
              const SizedBox(height: 24),
              _HistorySection(
                title: 'Payout history',
                seeAll: sortedPayouts.length > 1,
                empty: const RiderEmptyState(
                  icon: Icons.account_balance_outlined,
                  title: 'No payouts yet',
                  message:
                      'Requested and completed Stripe payouts will appear here.',
                ),
                rows:
                    sortedPayouts.take(6).map(_PayoutTimelineRow.new).toList(),
              ),
              const SizedBox(height: 24),
              _HistorySection(
                title: 'Transactions',
                seeAll: sortedTransactions.length > 12,
                empty: const RiderEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No earnings activity yet',
                  message:
                      'Completed delivery earnings and adjustments will appear here.',
                ),
                rows: sortedTransactions
                    .take(12)
                    .map(_ExpandableTransactionRow.new)
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _requestWithdrawal(
      BuildContext context, double available) async {
    final controller = TextEditingController();
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: _EarningsGlass(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Request withdrawal',
                  style: TextStyle(
                    color: RiderPalette.paper,
                    fontFamily: RiderTypography.heading,
                    fontSize: 25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Available ${_money(available)}',
                  style: const TextStyle(color: RiderPalette.muted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    color: RiderPalette.paper,
                    fontFamily: RiderTypography.mono,
                  ),
                  decoration: InputDecoration(
                    prefixText: '£ ',
                    prefixStyle: const TextStyle(color: RiderPalette.paper),
                    hintText: '0.00',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: .05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                RiderPrimaryButton(
                  label: 'Continue with Stripe',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () {
                    final value = double.tryParse(controller.text.trim());
                    if (value == null || value <= 0 || value > available) {
                      return;
                    }
                    Navigator.pop(sheetContext, value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    if (amount == null || !context.mounted) return;
    context.read<AccountBloc>().add(RequestWithdrawal(
          amount: amount.toStringAsFixed(2),
          sortCode: '',
          bankName: '',
          accountNumber: '',
          address: '',
          saveAccountDetails: false,
        ));
  }
}

class _PayoutSetupBanner extends StatelessWidget {
  const _PayoutSetupBanner({
    required this.readiness,
    required this.busy,
    required this.onPressed,
  });

  final RiderPayoutReadiness readiness;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => _EarningsGlass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              riderPayoutReadinessLabel(readiness),
              style: const TextStyle(
                color: RiderPalette.paper,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              riderPayoutReadinessBody(readiness),
              style: const TextStyle(
                color: RiderPalette.muted,
                height: 1.45,
              ),
            ),
            if (onPressed != null) ...[
              const SizedBox(height: 14),
              RiderPrimaryButton(
                label: riderPayoutReadinessActionLabel(readiness),
                icon: Icons.open_in_new_rounded,
                busy: busy,
                onPressed: onPressed,
              ),
            ],
          ],
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          if (Navigator.canPop(context)) ...[
            Semantics(
              button: true,
              label: 'Back',
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .045),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: .09)),
                  ),
                  child: const Icon(Icons.chevron_left_rounded,
                      color: RiderPalette.paper),
                ),
              ),
            ),
            const SizedBox(width: 14),
          ],
          const Text(
            'Earnings',
            style: TextStyle(
              color: RiderPalette.paper,
              fontFamily: RiderTypography.heading,
              fontSize: 30,
            ),
          ),
        ],
      );
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.available,
    required this.readiness,
    required this.reconciled,
    required this.unexplained,
    required this.activePayout,
    required this.payouts,
    required this.reviewRequired,
    required this.reviewMessage,
    required this.busy,
    required this.onWithdraw,
  });

  final double available;
  final String readiness;
  final bool reconciled;
  final double unexplained;
  final Map<String, dynamic>? activePayout;
  final List<Map<String, dynamic>> payouts;
  final bool reviewRequired;
  final String reviewMessage;
  final bool busy;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) => _EarningsGlass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _money(available),
              style: const TextStyle(
                color: RiderPalette.paper,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Available balance',
              style: TextStyle(color: RiderPalette.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            RiderPrimaryButton(
              label: _withdrawalLabel(readiness, activePayout, payouts),
              icon: Icons.account_balance_wallet_outlined,
              busy: busy,
              onPressed: onWithdraw,
            ),
            if (activePayout != null) ...[
              const SizedBox(height: 14),
              _PayoutStatusCard(
                payout: activePayout!,
              ),
            ],
            if (reviewRequired) ...[
              const SizedBox(height: 14),
              _StatusBanner(
                title: 'Review required',
                message: reviewMessage,
                warning: true,
              ),
            ],
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: .07)),
                ),
              ),
              child: const Text(
                'Cash payouts use your approved Stripe Connect account. Roth remains separate and cannot be withdrawn.',
                style: TextStyle(
                  color: RiderPalette.muted,
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
}

class _BreakdownGrid extends StatelessWidget {
  const _BreakdownGrid({
    required this.delivery,
    required this.tips,
    required this.waiting,
    required this.adjustments,
    required this.withdrawn,
    required this.settlement,
  });

  final double delivery;
  final double tips;
  final double waiting;
  final double adjustments;
  final double withdrawn;
  final double settlement;

  @override
  Widget build(BuildContext context) {
    final extraTiles = <Widget>[
      if (withdrawn.abs() > 0.009)
        _BreakdownTile(
          icon: Icons.account_balance_outlined,
          color: RiderPalette.green,
          value: _money(withdrawn),
          label: 'Withdrawn',
        ),
      if (settlement.abs() > 0.009)
        _BreakdownTile(
          icon: Icons.sync_alt_rounded,
          color: RiderPalette.blue,
          value: _signedMoney(settlement),
          label: settlement > 0 ? 'Pending Settlement' : 'Settlement Offset',
        ),
    ];
    final tiles = <Widget>[
      _BreakdownTile(
        icon: Icons.north_east_rounded,
        color: RiderPalette.blue,
        value: _money(delivery),
        label: 'Deliveries',
      ),
      _BreakdownTile(
        icon: Icons.payments_outlined,
        color: RiderPalette.purple,
        value: _money(tips),
        label: 'Tips',
      ),
      _BreakdownTile(
        icon: Icons.schedule_rounded,
        color: RiderPalette.amber,
        value: _money(waiting),
        label: 'Waiting & No-show',
      ),
      _BreakdownTile(
        icon: Icons.format_align_left_rounded,
        color: RiderPalette.muted,
        value: _money(adjustments),
        label: 'Adjustments',
      ),
      ...extraTiles,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Breakdown'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.52,
          children: tiles,
        ),
      ],
    );
  }
}

class _SummaryMetricGrid extends StatelessWidget {
  const _SummaryMetricGrid({
    required this.available,
    required this.pending,
    required this.processing,
    required this.lifetime,
  });

  final double available;
  final double pending;
  final double processing;
  final double lifetime;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.75,
        children: [
          _SummaryMetricTile(
            icon: Icons.account_balance_wallet_outlined,
            color: RiderPalette.green,
            value: _money(available),
            label: 'Available Balance',
          ),
          _SummaryMetricTile(
            icon: Icons.pending_actions_rounded,
            color: RiderPalette.amber,
            value: _money(pending),
            label: 'Pending Payout',
          ),
          _SummaryMetricTile(
            icon: Icons.sync_rounded,
            color: RiderPalette.blue,
            value: _money(processing),
            label: 'Processing',
          ),
          _SummaryMetricTile(
            icon: Icons.trending_up_rounded,
            color: RiderPalette.purple,
            value: _money(lifetime),
            label: 'Lifetime Earnings',
          ),
        ],
      );
}

class _SummaryMetricTile extends StatelessWidget {
  const _SummaryMetricTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$label $value',
        child: _EarningsGlass(
          radius: 18,
          blur: 12,
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              _IconBox(icon: icon, color: color, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 420),
                      tween: Tween(begin: 0, end: 1),
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: child,
                      ),
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RiderPalette.paper,
                          fontFamily: RiderTypography.mono,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RiderPalette.muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _BreakdownTile extends StatelessWidget {
  const _BreakdownTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => _EarningsGlass(
        radius: 18,
        blur: 12,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _IconBox(icon: icon, color: color, size: 32),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: RiderPalette.paper,
                    fontFamily: RiderTypography.mono,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    color: RiderPalette.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .3,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _PerformanceSection extends StatelessWidget {
  const _PerformanceSection({
    required this.summary,
    required this.storedEarnings,
    required this.transactions,
  });

  final Map<String, dynamic> summary;
  final Map<String, dynamic> storedEarnings;
  final List<Map<String, dynamic>> transactions;

  @override
  Widget build(BuildContext context) {
    final completed = _intValue(summary['completedDeliveries'] ??
        summary['completedJobs'] ??
        storedEarnings['completedDeliveries']);
    final weekly = _periodTotal(transactions, const Duration(days: 7));
    final monthly = _periodTotal(transactions, const Duration(days: 30));
    final trust = _number(summary['trustScore'] ??
        summary['trustPoints'] ??
        storedEarnings['trustScore'] ??
        storedEarnings['trustPoints']);
    final rank =
        '${summary['currentRank'] ?? summary['riderRank'] ?? storedEarnings['riderRank'] ?? 'Agent'}';
    final acceptance = _percentage(summary['acceptanceRate'] ??
        summary['acceptance'] ??
        storedEarnings['acceptanceRate']);
    final completion = _percentage(summary['completionRate'] ??
        summary['completion'] ??
        storedEarnings['completionRate']);
    final rating = _rating(summary['averageRating'] ??
        summary['rating'] ??
        storedEarnings['averageRating']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Rider performance'),
        const SizedBox(height: 8),
        _EarningsGlass(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PerformancePill(
                label: 'Trust Score',
                value: trust.toStringAsFixed(trust % 1 == 0 ? 0 : 1),
                icon: Icons.verified_user_outlined,
                color: RiderPalette.blue,
              ),
              _PerformancePill(
                label: 'Current Rank',
                value: _title(rank),
                icon: Icons.workspace_premium_outlined,
                color: RiderPalette.purple,
              ),
              _PerformancePill(
                label: 'Completed Deliveries',
                value: '$completed',
                icon: Icons.check_circle_outline_rounded,
                color: RiderPalette.green,
              ),
              _PerformancePill(
                label: 'Acceptance Rate',
                value: acceptance,
                icon: Icons.touch_app_outlined,
                color: RiderPalette.amber,
              ),
              _PerformancePill(
                label: 'Completion Rate',
                value: completion,
                icon: Icons.flag_outlined,
                color: RiderPalette.green,
              ),
              _PerformancePill(
                label: 'Weekly Earnings',
                value: _money(weekly),
                icon: Icons.calendar_view_week_outlined,
                color: RiderPalette.blue,
              ),
              _PerformancePill(
                label: 'Monthly Earnings',
                value: _money(monthly),
                icon: Icons.calendar_month_outlined,
                color: RiderPalette.purple,
              ),
              _PerformancePill(
                label: 'Average Rating',
                value: rating,
                icon: Icons.star_border_rounded,
                color: RiderPalette.amber,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PerformancePill extends StatelessWidget {
  const _PerformancePill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$label $value',
        child: Container(
          width: 154,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .035),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: .075)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 9),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RiderPalette.paper,
                  fontFamily: RiderTypography.mono,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RiderPalette.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
}

class _AnalyticsSection extends StatelessWidget {
  const _AnalyticsSection({required this.transactions});

  final List<Map<String, dynamic>> transactions;

  @override
  Widget build(BuildContext context) {
    final week = _periodTotal(transactions, const Duration(days: 7));
    final month = _periodTotal(transactions, const Duration(days: 30));
    final average = transactions.isEmpty
        ? 0.0
        : transactions
                .map((item) => _number(item['amount']))
                .where((amount) => amount > 0)
                .fold<double>(0, (total, amount) => total + amount) /
            transactions
                .where((item) => _number(item['amount']) > 0)
                .length
                .clamp(1, transactions.length);
    final topDay = _topEarningDay(transactions);
    final peakHour = _peakWorkingHour(transactions);
    final trend = month >= week ? 'Building' : 'Cooling';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Analytics'),
        const SizedBox(height: 8),
        _EarningsGlass(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _AnalyticsCard(
                      label: 'This Week',
                      value: _money(week),
                      color: RiderPalette.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AnalyticsCard(
                      label: 'Last 30 Days',
                      value: _money(month),
                      color: RiderPalette.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _AnalyticsCard(
                      label: 'Monthly trend',
                      value: trend,
                      color: RiderPalette.purple,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AnalyticsCard(
                      label: 'Average job value',
                      value: _money(average.isFinite ? average : 0),
                      color: RiderPalette.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _AnalyticsCard(
                      label: 'Top earning days',
                      value: topDay,
                      color: RiderPalette.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AnalyticsCard(
                      label: 'Peak working hours',
                      value: peakHour,
                      color: RiderPalette.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: .16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: RiderPalette.paper,
                fontFamily: RiderTypography.mono,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.title,
    required this.seeAll,
    required this.empty,
    required this.rows,
  });

  final String title;
  final bool seeAll;
  final Widget empty;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: RiderPalette.paper,
                    fontFamily: RiderTypography.heading,
                    fontSize: 22,
                  ),
                ),
              ),
              if (seeAll)
                const Text(
                  'View all',
                  style: TextStyle(
                    color: RiderPalette.blue,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            empty
          else
            _EarningsGlass(
              padding: EdgeInsets.zero,
              radius: 20,
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    rows[i],
                    if (i != rows.length - 1) const _Hairline(),
                  ],
                ],
              ),
            ),
        ],
      );
}

class _PayoutTimelineRow extends StatelessWidget {
  const _PayoutTimelineRow(this.item);

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final status = '${item['status'] ?? item['payoutStatus'] ?? 'pending'}';
    final failed = status.toLowerCase().contains('fail') ||
        status.toLowerCase().contains('reject');
    final paid = status.toLowerCase().contains('paid') ||
        status.toLowerCase().contains('complete');
    final amount = _number(item['amount'] ?? item['riderGrossShare']);
    final reason =
        '${item['failureReason'] ?? item['reviewReason'] ?? ''}'.trim();
    final subtitle = [
      _date(item),
      if (reason.isNotEmpty) reason,
    ].join(' · ');

    final statusColor = failed
        ? RiderPalette.red
        : paid
            ? RiderPalette.green
            : RiderPalette.blue;
    final label = _title(status).isEmpty ? 'Processing' : _title(status);
    final reference =
        '${item['stripePayoutId'] ?? item['payoutId'] ?? item['id'] ?? ''}'
            .trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PayoutStepper(status: status.toLowerCase(), color: statusColor),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: RiderPalette.paper,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      _money(amount),
                      style: const TextStyle(
                        color: RiderPalette.paper,
                        fontFamily: RiderTypography.mono,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: RiderPalette.muted,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _TinyPill(label: label.toUpperCase(), color: statusColor),
                    if (_estimatedArrival(item) != null)
                      _TinyPill(
                        label: 'ETA ${_estimatedArrival(item)!}',
                        color: RiderPalette.blue,
                      ),
                    if (reference.isNotEmpty)
                      _TinyPill(
                        label: 'REF ${_shortRef(reference)}',
                        color: RiderPalette.muted,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutStepper extends StatelessWidget {
  const _PayoutStepper({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final stages = ['Available', 'Requested', 'Processing', 'Paid'];
    final index = status.contains('paid') || status.contains('complete')
        ? 3
        : status.contains('process')
            ? 2
            : status.contains('request') || status.contains('pending')
                ? 1
                : 0;
    return Column(
      children: [
        for (var i = 0; i < stages.length; i++) ...[
          Tooltip(
            message: stages[i],
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: i <= index ? color : Colors.white.withValues(alpha: .16),
                shape: BoxShape.circle,
              ),
            ),
          ),
          if (i != stages.length - 1)
            Container(
              width: 2,
              height: 12,
              color: i < index
                  ? color.withValues(alpha: .55)
                  : Colors.white.withValues(alpha: .12),
            ),
        ],
      ],
    );
  }
}

class _ExpandableTransactionRow extends StatelessWidget {
  const _ExpandableTransactionRow(this.item);

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final type = '${item['type'] ?? item['category'] ?? 'earning'}';
    final amount = _number(item['amount']);
    final status = _transactionStatus(item);
    final isDebit = amount < 0 ||
        type.toLowerCase().contains('debit') ||
        type.toLowerCase().contains('payout') ||
        type.toLowerCase().contains('reversal');
    final reference =
        '${item['paymentReference'] ?? item['paymentIntentId'] ?? item['deliveryId'] ?? item['id'] ?? ''}'
            .trim();
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.white.withValues(alpha: .04),
        highlightColor: Colors.white.withValues(alpha: .03),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: RiderPalette.blue,
        collapsedIconColor: RiderPalette.muted,
        leading: _IconBox(
          icon: _transactionIcon(type, isDebit),
          color: isDebit ? RiderPalette.red : RiderPalette.green,
          size: 36,
        ),
        title: Text(
          _transactionTitle(type),
          style: const TextStyle(
            color: RiderPalette.paper,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _date(item),
                style: const TextStyle(
                  color: RiderPalette.muted,
                  fontSize: 11.5,
                ),
              ),
              _TinyPill(label: status, color: _statusColor(status)),
            ],
          ),
        ),
        trailing: Text(
          _signedMoney(amount),
          style: TextStyle(
            color: isDebit ? RiderPalette.muted : RiderPalette.paper,
            fontFamily: RiderTypography.mono,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        children: [
          _TransactionDetailGrid(item: item, reference: reference),
        ],
      ),
    );
  }

  static IconData _transactionIcon(String type, bool isDebit) {
    final value = type.toLowerCase();
    if (isDebit) return Icons.remove_rounded;
    if (value.contains('tip')) return Icons.payments_outlined;
    if (value.contains('wait') || value.contains('no_show')) {
      return Icons.schedule_rounded;
    }
    if (value.contains('adjust')) return Icons.tune_rounded;
    return Icons.local_shipping_outlined;
  }

  static String _transactionTitle(String type) {
    final value = type.toLowerCase();
    if (value.contains('delivery')) return 'Delivery';
    if (value.contains('tip')) return 'Tip';
    if (value.contains('waiting') || value.contains('no_show')) {
      return 'Waiting & No-show';
    }
    if (value.contains('adjustment')) return 'Adjustment';
    if (value.contains('payout')) return 'Payout';
    if (value.contains('reversal') || value.contains('correction')) {
      return 'Correction';
    }
    return _title(type);
  }
}

class _TransactionDetailGrid extends StatelessWidget {
  const _TransactionDetailGrid({
    required this.item,
    required this.reference,
  });

  final Map<String, dynamic> item;
  final String reference;

  @override
  Widget build(BuildContext context) {
    final fields = <MapEntry<String, String>>[
      MapEntry('Delivery ID', _clean(item['deliveryId'] ?? item['jobId'])),
      MapEntry('Customer', _clean(item['customerName'] ?? item['senderName'])),
      MapEntry('Distance', _clean(item['distanceLabel'] ?? item['distance'])),
      MapEntry('Vehicle', _clean(item['vehicle'] ?? item['vehicleLabel'])),
      MapEntry('Tip', _money(_number(item['tip']))),
      MapEntry('Fees', _money(_number(item['fees'] ?? item['fee']))),
      MapEntry(
          'Roth earned', _clean(item['rothEarned'] ?? item['roth'] ?? '0')),
      MapEntry('Date', _date(item)),
      MapEntry('Time', _time(item)),
      MapEntry('Status', _transactionStatus(item)),
      MapEntry(
          'Payment reference', reference.isEmpty ? 'Not available' : reference),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        children: [
          for (final field in fields) ...[
            _DetailLine(label: field.key, value: field.value),
            if (field.key != fields.last.key) const SizedBox(height: 8),
          ],
          if (reference.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: reference));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reference copied.')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy reference'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                color: RiderPalette.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: RiderPalette.paper,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
}

class _PayoutStatusCard extends StatelessWidget {
  const _PayoutStatusCard({required this.payout});

  final Map<String, dynamic> payout;

  @override
  Widget build(BuildContext context) {
    final amount = _number(payout['amount'] ?? payout['riderGrossShare']);
    final status = _payoutStatusLabel(payout);
    final arrival = _estimatedArrival(payout);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          _IconBox(
            icon: Icons.account_balance_wallet_outlined,
            color: _statusColor(status),
            size: 34,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$status · ${_money(amount)}',
                  style: const TextStyle(
                    color: RiderPalette.paper,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  arrival == null
                      ? 'Payout status updates automatically.'
                      : 'Estimated arrival $arrival',
                  style: const TextStyle(
                    color: RiderPalette.muted,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoEarningsState extends StatelessWidget {
  const _NoEarningsState();

  @override
  Widget build(BuildContext context) => const _EarningsGlass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBox(
              icon: Icons.account_balance_wallet_outlined,
              color: RiderPalette.blue,
              size: 42,
            ),
            SizedBox(height: 16),
            Text(
              'No earnings yet',
              style: TextStyle(
                color: RiderPalette.paper,
                fontFamily: RiderTypography.heading,
                fontSize: 26,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Completed delivery earnings, tips, waiting payments and adjustments will appear here.',
              style: TextStyle(
                color: RiderPalette.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.title,
    required this.message,
    required this.warning,
  });

  final String title;
  final String message;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? RiderPalette.red : RiderPalette.blue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: warning ? .07 : .06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: warning ? .26 : .22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: .22),
                  blurRadius: 0,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: RiderPalette.paper,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: RiderPalette.muted,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: .3,
          ),
        ),
      );
}

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(size > 34 ? 11 : 10),
        ),
        child: Icon(icon, color: color, size: size > 34 ? 18 : 16),
      );
}

class _EarningsGlass extends StatelessWidget {
  const _EarningsGlass({
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.radius = 22,
    this.blur = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: RiderPalette.panel.withValues(alpha: .78),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white.withValues(alpha: .09)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .35),
                  blurRadius: 34,
                  offset: const Offset(0, 14),
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: .045),
                  RiderPalette.panel.withValues(alpha: .78),
                ],
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: .38),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      );
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        indent: 16,
        endIndent: 16,
        color: Colors.white.withValues(alpha: .07),
      );
}

class _EarningsLoading extends StatelessWidget {
  const _EarningsLoading();

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: RiderPalette.blue),
      );
}

class _EarningsFailure extends StatelessWidget {
  const _EarningsFailure({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            const _TopBar(),
            const SizedBox(height: 18),
            RiderEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Earnings unavailable',
              message: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: onRetry,
            ),
          ],
        ),
      );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

double _number(Object? value) => value is num ? value.toDouble() : 0;

int _intValue(Object? value) => value is num ? value.toInt() : 0;

bool _isActivePayout(Map<String, dynamic> item) {
  final status =
      '${item['status'] ?? item['payoutStatus'] ?? ''}'.toLowerCase();
  return {'requested', 'pending', 'approved', 'processing'}.contains(status);
}

bool _isPaidPayout(Map<String, dynamic> item) {
  final status =
      '${item['status'] ?? item['payoutStatus'] ?? ''}'.toLowerCase();
  return status.contains('paid') ||
      status.contains('complete') ||
      status.contains('settled');
}

double _payoutAmount(Map<String, dynamic> item) =>
    _number(item['amount'] ?? item['riderGrossShare']);

bool _requiresPayoutReview(
    Map<String, dynamic> summary, Map<String, dynamic>? activePayout) {
  final readiness = '${summary['connectReadiness'] ?? ''}'.toLowerCase();
  final payoutStatus =
      '${activePayout?['status'] ?? activePayout?['payoutStatus'] ?? ''}'
          .toLowerCase();
  return summary['accountReviewRequired'] == true ||
      summary['payoutHold'] == true ||
      summary['payoutReviewRequired'] == true ||
      readiness.contains('review') ||
      readiness.contains('hold') ||
      payoutStatus.contains('review') ||
      payoutStatus.contains('hold') ||
      '${activePayout?['reviewReason'] ?? ''}'.trim().isNotEmpty;
}

String _reviewMessage(Map<String, dynamic> summary,
    Map<String, dynamic>? activePayout, double unexplained) {
  final reason =
      '${activePayout?['reviewReason'] ?? summary['reviewReason'] ?? summary['payoutHoldReason'] ?? ''}'
          .trim();
  if (reason.isNotEmpty) return reason;
  if (unexplained.abs() > 0.009) {
    return '${_money(unexplained.abs())} is under payout review.';
  }
  return 'Your payout is under review. We will update this status automatically.';
}

String _payoutStatusLabel(Map<String, dynamic> item) {
  final status = _title('${item['status'] ?? item['payoutStatus'] ?? ''}');
  return status.isEmpty ? 'Processing' : status;
}

String? _estimatedArrival(Map<String, dynamic> item) {
  final value = item['estimatedArrival'] ??
      item['estimatedArrivalAt'] ??
      item['expectedArrival'] ??
      item['expectedArrivalAt'] ??
      item['arrivalAt'];
  if (value is Timestamp) return _formatDateTime(value);
  final text = '$value'.trim();
  return text.isEmpty || text == 'null' ? null : text;
}

String _transactionStatus(Map<String, dynamic> item) {
  final raw =
      '${item['status'] ?? item['ledgerStatus'] ?? item['payoutStatus'] ?? ''}'
          .trim()
          .toLowerCase();
  if (raw.contains('paid') ||
      raw.contains('complete') ||
      raw.contains('settled')) {
    return 'Paid';
  }
  if (raw.contains('pending') ||
      raw.contains('processing') ||
      raw.contains('review')) {
    return 'Pending';
  }
  if (raw.contains('available') ||
      raw.contains('posted') ||
      raw.contains('cleared')) {
    return 'Available';
  }
  return 'Available';
}

Color _statusColor(String status) {
  final value = status.toLowerCase();
  if (value.contains('paid') ||
      value.contains('available') ||
      value.contains('complete') ||
      value.contains('settled')) {
    return RiderPalette.green;
  }
  if (value.contains('fail') || value.contains('reject')) {
    return RiderPalette.red;
  }
  if (value.contains('review') || value.contains('hold')) {
    return RiderPalette.amber;
  }
  return RiderPalette.blue;
}

Map<String, dynamic>? _firstWhereOrNull(
  Iterable<Map<String, dynamic>> items,
  bool Function(Map<String, dynamic>) test,
) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

String _withdrawalLabel(String readiness, Map<String, dynamic>? active,
    List<Map<String, dynamic>> payouts) {
  if (readiness == 'setup_required' ||
      readiness == 'restricted' ||
      readiness == 'disabled') {
    return 'Complete payout setup';
  }
  if (readiness == 'pending_verification') return 'Verification pending';
  if (active != null) {
    final amount = _number(active['amount']);
    return amount > 0
        ? 'Payout processing — ${_money(amount)}'
        : 'Payout processing';
  }
  final failed = _firstWhereOrNull(
    payouts,
    (p) => '${p['status'] ?? p['payoutStatus']}'.toLowerCase() == 'failed',
  );
  if (failed != null) return 'Payout failed';
  return 'Request withdrawal';
}

String _money(double value) => '£${value.toStringAsFixed(2)}';

String _signedMoney(double value) {
  if (value < 0) return '−£${value.abs().toStringAsFixed(2)}';
  return _money(value);
}

String _percentage(Object? value) {
  final number = _number(value);
  if (number <= 0) return '0%';
  final percent = number <= 1 ? number * 100 : number;
  return '${percent.toStringAsFixed(percent % 1 == 0 ? 0 : 1)}%';
}

String _rating(Object? value) {
  final number = _number(value);
  if (number <= 0) return '0.0';
  return number.toStringAsFixed(1);
}

double _periodTotal(List<Map<String, dynamic>> items, Duration period) {
  final cutoff = DateTime.now().subtract(period).millisecondsSinceEpoch;
  return items
      .where((item) => _millis(item) >= cutoff)
      .map((item) => _number(item['amount']))
      .where((amount) => amount > 0)
      .fold<double>(0, (total, amount) => total + amount);
}

String _topEarningDay(List<Map<String, dynamic>> items) {
  final totals = <int, double>{};
  for (final item in items) {
    final timestamp = _timestamp(item);
    if (timestamp == null) continue;
    final day = DateTime(timestamp.year, timestamp.month, timestamp.day)
        .millisecondsSinceEpoch;
    totals[day] = (totals[day] ?? 0) + _number(item['amount']);
  }
  if (totals.isEmpty) return 'No data yet';
  final top = totals.entries.reduce(
    (a, b) => a.value >= b.value ? a : b,
  );
  final date = DateTime.fromMillisecondsSinceEpoch(top.key);
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

String _peakWorkingHour(List<Map<String, dynamic>> items) {
  final totals = <int, int>{};
  for (final item in items) {
    final timestamp = _timestamp(item);
    if (timestamp == null) continue;
    totals[timestamp.hour] = (totals[timestamp.hour] ?? 0) + 1;
  }
  if (totals.isEmpty) return 'No data yet';
  final top = totals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  final end = (top + 1) % 24;
  return '${top.toString().padLeft(2, '0')}:00-${end.toString().padLeft(2, '0')}:00';
}

int _millis(Map<String, dynamic> item) {
  return _timestamp(item)?.millisecondsSinceEpoch ?? 0;
}

DateTime? _timestamp(Map<String, dynamic> item) {
  final value = item['createdAt'] ??
      item['updatedAt'] ??
      item['paidAt'] ??
      item['completedAt'] ??
      item['availableAt'];
  return value is Timestamp ? value.toDate().toLocal() : null;
}

String _title(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _date(Map<String, dynamic> item) {
  final value = _timestamp(item);
  if (value == null) return 'Status pending';
  return _formatDate(value);
}

String _time(Map<String, dynamic> item) {
  final value = _timestamp(item);
  if (value == null) return 'Pending';
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _clean(Object? value) {
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return 'Not available';
  return text;
}

String _shortRef(String value) {
  if (value.length <= 10) return value;
  return '${value.substring(0, 6)}…${value.substring(value.length - 4)}';
}

String _formatDateTime(Timestamp value) {
  return _formatDate(value.toDate().toLocal());
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} · $hour:$minute';
}
