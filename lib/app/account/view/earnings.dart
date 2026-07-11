import 'package:cloud_firestore/cloud_firestore.dart';
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
  @override
  void initState() {
    super.initState();
    context.read<AccountBloc>()
      ..add(GetEarnings())
      ..add(GetRequests());
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
    final content = StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
                        context.read<AccountBloc>().add(GetEarnings()),
                  );
                }
                final wallet = earningsSnapshot.data?.data() ?? const {};
                final payouts = payoutSnapshot.data?.docs
                        .map((doc) => {'id': doc.id, ...doc.data()})
                        .toList() ??
                    const <Map<String, dynamic>>[];
                final transactions = transactionSnapshot.data?.docs
                        .map((doc) => {'id': doc.id, ...doc.data()})
                        .toList() ??
                    const <Map<String, dynamic>>[];
                return _EarningsContent(
                  wallet: wallet,
                  payouts: payouts,
                  transactions: transactions,
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
      appBar: AppBar(
        backgroundColor: RiderPalette.background,
        foregroundColor: RiderPalette.paper,
        elevation: 0,
        title: const Text('Earnings'),
      ),
      body: content,
    );
  }
}

class _EarningsContent extends StatelessWidget {
  const _EarningsContent({
    required this.wallet,
    required this.payouts,
    required this.transactions,
  });

  final Map<String, dynamic> wallet;
  final List<Map<String, dynamic>> payouts;
  final List<Map<String, dynamic>> transactions;

  @override
  Widget build(BuildContext context) {
    final available =
        _num(wallet['availableBalance'] ?? wallet['accountBalance']);
    final pending = _num(wallet['pendingBalance'] ?? wallet['pendingEarnings']);
    final delivery = _sumType(transactions, ['delivery', 'earning']);
    final tips = _sumType(transactions, ['tip']);
    final waiting = _sumType(transactions, ['waiting', 'no_show']);
    final adjustments = _sumType(transactions, ['adjustment', 'refund']);
    final pendingPayout = payouts.any((item) => {
          'requested',
          'pending',
          'approved',
          'processing',
        }.contains(
            '${item['status'] ?? item['payoutStatus'] ?? ''}'.toLowerCase()));
    final sortedPayouts = [...payouts]
      ..sort((a, b) => _millis(b).compareTo(_millis(a)));
    final sortedTransactions = [...transactions]
      ..sort((a, b) => _millis(b).compareTo(_millis(a)));
    return BlocBuilder<AccountBloc, AccountState>(
      builder: (context, account) => ListView(
        key: const PageStorageKey('rider-earnings'),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          const Text('Earnings',
              style: TextStyle(
                  color: RiderPalette.paper,
                  fontFamily: RiderTypography.heading,
                  fontSize: 30)),
          const SizedBox(height: 16),
          RiderGlassCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const RiderStatusBadge('CASH EARNINGS',
                  color: RiderPalette.green),
              const SizedBox(height: 16),
              RiderMoney('£${available.toStringAsFixed(2)}',
                  label: 'Available to withdraw', size: 38),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: RiderMetric(
                        value: '£${pending.toStringAsFixed(2)}',
                        label: 'PENDING')),
                const SizedBox(width: 9),
                Expanded(
                    child: RiderMetric(
                        value: '${transactions.length}', label: 'ACTIVITY')),
              ]),
              const SizedBox(height: 15),
              RiderPrimaryButton(
                label: pendingPayout
                    ? 'Withdrawal processing'
                    : 'Request withdrawal',
                icon: Icons.account_balance_rounded,
                busy: account.status == AccountStatus.loading,
                onPressed: pendingPayout || available <= 0
                    ? null
                    : () => _requestWithdrawal(context, available),
              ),
              const SizedBox(height: 10),
              const Text(
                'Cash payouts use your approved Stripe Connect account. Roth remains separate and cannot be withdrawn.',
                style: TextStyle(
                    color: RiderPalette.muted, fontSize: 11, height: 1.4),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            childAspectRatio: 1.75,
            children: [
              RiderMetric(value: _money(delivery), label: 'DELIVERIES'),
              RiderMetric(value: _money(tips), label: 'TIPS'),
              RiderMetric(value: _money(waiting), label: 'WAITING / NO-SHOW'),
              RiderMetric(value: _money(adjustments), label: 'ADJUSTMENTS'),
            ],
          ),
          const SizedBox(height: 22),
          const RiderSectionTitle('Payout history'),
          const SizedBox(height: 10),
          if (sortedPayouts.isEmpty)
            const RiderEmptyState(
              icon: Icons.account_balance_outlined,
              title: 'No payouts yet',
              message:
                  'Requested and completed Stripe payouts will appear here.',
            )
          else
            RiderGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: Column(
                children: sortedPayouts.take(6).map(_PayoutRow.new).toList(),
              ),
            ),
          const SizedBox(height: 22),
          const RiderSectionTitle('Earnings activity'),
          const SizedBox(height: 10),
          if (sortedTransactions.isEmpty)
            const RiderEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No earnings activity yet',
              message:
                  'Completed delivery earnings and adjustments will appear here.',
            )
          else
            RiderGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: Column(
                children: sortedTransactions
                    .take(12)
                    .map(_TransactionRow.new)
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _requestWithdrawal(
      BuildContext context, double available) async {
    final controller = TextEditingController();
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RiderPalette.panel,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Request withdrawal',
                style: TextStyle(
                    color: RiderPalette.paper,
                    fontFamily: RiderTypography.heading,
                    fontSize: 24)),
            const SizedBox(height: 8),
            Text('Available £${available.toStringAsFixed(2)}',
                style: const TextStyle(color: RiderPalette.muted)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: RiderPalette.paper),
              decoration: InputDecoration(
                prefixText: '£ ',
                prefixStyle: const TextStyle(color: RiderPalette.paper),
                hintText: '0.00',
                filled: true,
                fillColor: Colors.white.withOpacity(.05),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            RiderPrimaryButton(
              label: 'Continue with Stripe',
              icon: Icons.arrow_forward_rounded,
              onPressed: () {
                final value = double.tryParse(controller.text.trim());
                if (value == null || value <= 0 || value > available) return;
                Navigator.pop(sheetContext, value);
              },
            ),
          ]),
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

  static double _sumType(List<Map<String, dynamic>> rows, List<String> types) {
    return rows.where((item) {
      final value = '${item['type'] ?? item['category'] ?? ''}'.toLowerCase();
      return types.any(value.contains);
    }).fold(0, (sum, item) => sum + _num(item['amount']));
  }

  static double _num(Object? value) => value is num ? value.toDouble() : 0;
  static String _money(double value) => '£${value.toStringAsFixed(2)}';
  static int _millis(Map<String, dynamic> item) {
    final value = item['createdAt'] ?? item['updatedAt'] ?? item['paidAt'];
    return value is Timestamp ? value.millisecondsSinceEpoch : 0;
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow(this.item);
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final status = '${item['status'] ?? item['payoutStatus'] ?? 'pending'}';
    final amount = item['amount'] ?? item['riderGrossShare'];
    final failed = status.toLowerCase().contains('fail') ||
        status.toLowerCase().contains('reject');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        failed ? Icons.error_outline_rounded : Icons.account_balance_rounded,
        color: failed ? RiderPalette.red : RiderPalette.blue,
      ),
      title: Text(_title(status),
          style: const TextStyle(
              color: RiderPalette.paper, fontWeight: FontWeight.w700)),
      subtitle: Text(_date(item),
          style: const TextStyle(color: RiderPalette.muted, fontSize: 11)),
      trailing: Text(amount is num ? '£${amount.toStringAsFixed(2)}' : '—',
          style: const TextStyle(
              color: RiderPalette.paper,
              fontFamily: RiderTypography.mono,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow(this.item);
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final type = '${item['type'] ?? item['category'] ?? 'earning'}';
    final amount = item['amount'];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading:
          const Icon(Icons.receipt_long_rounded, color: RiderPalette.green),
      title: Text(_title(type),
          style: const TextStyle(
              color: RiderPalette.paper, fontWeight: FontWeight.w700)),
      subtitle: Text('${item['description'] ?? item['status'] ?? _date(item)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: RiderPalette.muted, fontSize: 11)),
      trailing: Text(amount is num ? '£${amount.toStringAsFixed(2)}' : '—',
          style: const TextStyle(
              color: RiderPalette.paper,
              fontFamily: RiderTypography.mono,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _EarningsFailure extends StatelessWidget {
  const _EarningsFailure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(padding: const EdgeInsets.all(18), children: [
          const Text('Earnings',
              style: TextStyle(
                  color: RiderPalette.paper,
                  fontFamily: RiderTypography.heading,
                  fontSize: 30)),
          const SizedBox(height: 18),
          RiderEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Earnings unavailable',
            message: 'Check your connection and try again.',
            actionLabel: 'Retry',
            onAction: onRetry,
          ),
        ]),
      );
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
  final date = value.toDate().toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
