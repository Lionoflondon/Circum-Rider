import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../rider_design/rider_ui.dart';
import '../bloc/account_bloc.dart';

class EarningsView extends StatefulWidget {
  const EarningsView({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<EarningsView> createState() => _EarningsViewState();
}

class _EarningsViewState extends State<EarningsView> {
  late Future<Map<String, dynamic>> _summary;

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
  });

  final Map<String, dynamic> summary;
  final Map<String, dynamic> storedEarnings;
  final List<Map<String, dynamic>> payouts;
  final List<Map<String, dynamic>> transactions;
  final VoidCallback onRefresh;

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
    final delivery = _number(totals['delivery_earning']);
    final tips = _number(totals['tip']);
    final waiting =
        _number(totals['waiting_fee']) + _number(totals['no_show_fee']);
    final adjustments = _number(totals['adjustment_credit']) -
        _number(totals['adjustment_debit']);
    final unexplained = _number(summary['unexplained']);
    final reconciled = summary['reconciled'] == true;
    final readiness = '${summary['connectReadiness'] ?? 'setup_required'}';
    final activityCount = summary['activityCount'] is num
        ? (summary['activityCount'] as num).toInt()
        : transactions.length;

    final sortedPayouts = [...payouts]
      ..sort((a, b) => _millis(b).compareTo(_millis(a)));
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
            if (!hasEarnings) ...[
              const _NoEarningsState(),
            ] else ...[
              _BalanceHero(
                available: available,
                pending: pending,
                activityCount: activityCount,
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
              _BreakdownGrid(
                delivery: delivery,
                tips: tips,
                waiting: waiting,
                adjustments: adjustments,
              ),
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
                rows: sortedPayouts.take(6).map(_PayoutRow.new).toList(),
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
                    .map(_TransactionRow.new)
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
    required this.pending,
    required this.activityCount,
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
  final double pending;
  final int activityCount;
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
            Row(
              children: [
                if (pending > 0) ...[
                  Expanded(
                    child:
                        _MiniMetric(value: _money(pending), label: 'PENDING'),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: _MiniMetric(
                      value: '$activityCount', label: 'TRANSACTIONS'),
                ),
              ],
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
  });

  final double delivery;
  final double tips;
  final double waiting;
  final double adjustments;

  @override
  Widget build(BuildContext context) => Column(
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
            children: [
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
            ],
          ),
        ],
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

class _PayoutRow extends StatelessWidget {
  const _PayoutRow(this.item);

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

    return _LedgerRow(
      icon: failed
          ? Icons.error_outline_rounded
          : paid
              ? Icons.check_rounded
              : Icons.account_balance_wallet_outlined,
      iconColor: failed
          ? RiderPalette.red
          : paid
              ? RiderPalette.green
              : RiderPalette.blue,
      title: _title(status).isEmpty ? 'Processing' : _title(status),
      subtitle: subtitle,
      amount: _money(amount),
      status: _title(status).toUpperCase(),
      statusColor: failed
          ? RiderPalette.red
          : paid
              ? RiderPalette.green
              : RiderPalette.blue,
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow(this.item);

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
    return _LedgerRow(
      icon: _transactionIcon(type, isDebit),
      iconColor: isDebit ? RiderPalette.red : RiderPalette.green,
      title: _transactionTitle(type),
      subtitle: _date(item),
      amount: _signedMoney(amount),
      status: status,
      statusColor: _statusColor(status),
      amountMuted: isDebit,
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

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.status,
    this.statusColor,
    this.amountMuted = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String amount;
  final String? status;
  final Color? statusColor;
  final bool amountMuted;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _IconBox(icon: icon, color: iconColor, size: 36),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: RiderPalette.paper,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RiderPalette.muted,
                      fontSize: 11.5,
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 4),
                    _TinyPill(label: status!, color: statusColor!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              amount,
              style: TextStyle(
                color: amountMuted ? RiderPalette.muted : RiderPalette.paper,
                fontFamily: RiderTypography.mono,
                fontWeight: FontWeight.w900,
                fontSize: 14,
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

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .075)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: RiderPalette.paper,
                fontFamily: RiderTypography.mono,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: RiderPalette.muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .4,
              ),
            ),
          ],
        ),
      );
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

bool _isActivePayout(Map<String, dynamic> item) {
  final status =
      '${item['status'] ?? item['payoutStatus'] ?? ''}'.toLowerCase();
  return {'requested', 'pending', 'approved', 'processing'}.contains(status);
}

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

int _millis(Map<String, dynamic> item) {
  final value = item['createdAt'] ?? item['updatedAt'] ?? item['paidAt'];
  return value is Timestamp ? value.millisecondsSinceEpoch : 0;
}

String _title(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _date(Map<String, dynamic> item) {
  final value = item['createdAt'] ?? item['updatedAt'] ?? item['paidAt'];
  if (value is! Timestamp) return 'Status pending';
  return _formatDateTime(value);
}

String _formatDateTime(Timestamp value) {
  final date = value.toDate().toLocal();
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} · $hour:$minute';
}
