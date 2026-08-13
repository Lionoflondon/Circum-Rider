import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../rider_design/rider_ui.dart';

abstract interface class RiderRothWalletDataSource {
  Future<RiderRothWallet> loadWallet();

  Future<RiderRothTransactionPage> loadTransactions({String? pageToken});

  Future<RiderReferralDashboard> loadReferrals();
}

class RiderRothWalletRepository implements RiderRothWalletDataSource {
  RiderRothWalletRepository({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  @override
  Future<RiderRothWallet> loadWallet() async {
    final result = await _functions.httpsCallable('getRiderRothWallet').call();
    return RiderRothWallet.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  @override
  Future<RiderRothTransactionPage> loadTransactions({String? pageToken}) async {
    final result =
        await _functions.httpsCallable('getRiderRothTransactions').call({
      'pageSize': 20,
      if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
    });
    return RiderRothTransactionPage.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  @override
  Future<RiderReferralDashboard> loadReferrals() async {
    final codeResult =
        await _functions.httpsCallable('ensureReferralCode').call();
    final codeData = Map<String, dynamic>.from(codeResult.data as Map);
    final dashboardResult = await _functions
        .httpsCallable('getReferralDashboard')
        .call({'pageSize': 20});
    final dashboard = Map<String, dynamic>.from(dashboardResult.data as Map);
    return RiderReferralDashboard.fromMap({
      ...dashboard,
      'referralCode': dashboard['referralCode'] ?? codeData['referralCode'],
      'referralLink': dashboard['referralLink'] ?? codeData['referralLink'],
    });
  }
}

class RiderRothWallet {
  const RiderRothWallet({
    required this.balance,
    required this.status,
    required this.currency,
  });

  factory RiderRothWallet.fromMap(Map<String, dynamic> data) => RiderRothWallet(
        balance: _finiteAmount(data['balance']),
        status: '${data['status'] ?? 'active'}'.trim().toLowerCase(),
        currency: '${data['currency'] ?? 'ROTH'}'.trim().toUpperCase(),
      );

  final double balance;
  final String status;
  final String currency;

  bool get frozen => status == 'frozen';
}

class RiderRothTransactionPage {
  const RiderRothTransactionPage({
    required this.wallet,
    required this.transactions,
    this.nextPageToken,
  });

  factory RiderRothTransactionPage.fromMap(Map<String, dynamic> data) {
    final records = (data['transactions'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (item) =>
              RiderRothTransaction.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
    return RiderRothTransactionPage(
      wallet: RiderRothWallet.fromMap(data),
      transactions: records,
      nextPageToken: _optionalText(data['nextPageToken']),
    );
  }

  final RiderRothWallet wallet;
  final List<RiderRothTransaction> transactions;
  final String? nextPageToken;
}

class RiderRothTransaction {
  const RiderRothTransaction({
    required this.id,
    required this.type,
    required this.direction,
    required this.status,
    required this.description,
    required this.amount,
    required this.balanceAfter,
    this.relatedEntityId,
    this.createdAt,
  });

  factory RiderRothTransaction.fromMap(Map<String, dynamic> data) =>
      RiderRothTransaction(
        id: '${data['transactionId'] ?? ''}'.trim(),
        type: '${data['type'] ?? 'adjustment'}'.trim().toLowerCase(),
        direction: '${data['direction'] ?? 'credit'}'.trim().toLowerCase(),
        status: '${data['status'] ?? 'completed'}'.trim().toLowerCase(),
        description: '${data['description'] ?? 'Roth activity'}'.trim(),
        amount: _finiteAmount(data['amount']).abs(),
        balanceAfter: _finiteAmount(data['balanceAfter']),
        relatedEntityId: _optionalText(
          data['relatedEntityId'] ?? data['referenceId'],
        ),
        createdAt: _dateTime(data['createdAt']),
      );

  final String id;
  final String type;
  final String direction;
  final String status;
  final String description;
  final double amount;
  final double balanceAfter;
  final String? relatedEntityId;
  final DateTime? createdAt;

  bool get credit => direction != 'debit';

  String get title => switch (type) {
        'referral_reward' => 'Referral reward',
        'referral_welcome_reward' => 'Referral welcome reward',
        'refund_credit' || 'refund' => 'Roth refund',
        'promotional_reward' || 'reward_credit' => 'Roth reward',
        'gift_card_redeem' => 'Roth Card redeemed',
        'roth_spend' || 'checkout_spend' || 'roth_debit' => 'Roth used',
        'admin_issue' || 'admin_credit' || 'roth_credit' => 'Roth credited',
        'admin_debit' || 'reversal' => 'Roth adjustment',
        _ => description.isEmpty ? 'Roth activity' : description,
      };

  String get statusLabel => switch (status) {
        'completed' || 'succeeded' || 'success' => 'Completed',
        'pending' || 'processing' => 'Pending',
        'failed' => 'Failed',
        'reversed' || 'cancelled' => 'Reversed',
        _ => 'Status updating',
      };

  String get amountLabel => '${credit ? '+' : '-'}${formatRoth(amount)} Roth';
}

enum RiderReferralStage {
  invited,
  signedUp,
  qualified,
  credited,
  review,
  rejected,
  unknown,
}

class RiderReferralRecord {
  const RiderReferralRecord({
    required this.id,
    required this.stage,
    required this.rewardAmount,
    this.createdAt,
    this.qualifiedAt,
    this.rewardedAt,
  });

  factory RiderReferralRecord.fromMap(Map<String, dynamic> data) {
    final status =
        '${data['rewardStatus'] ?? data['status'] ?? ''}'.trim().toUpperCase();
    final stage = switch (status) {
      'INVITED' || 'PENDING' => RiderReferralStage.invited,
      'SIGNED_UP' || 'SIGNEDUP' => RiderReferralStage.signedUp,
      'FIRST_QUALIFYING_DELIVERY_COMPLETED' ||
      'ACTIVATED' ||
      'COMPLETED' =>
        RiderReferralStage.qualified,
      'ROTH_AWARDED' || 'REWARDED' => RiderReferralStage.credited,
      'REVIEW' => RiderReferralStage.review,
      'REJECTED' => RiderReferralStage.rejected,
      _ => RiderReferralStage.unknown,
    };
    return RiderReferralRecord(
      id: '${data['referralId'] ?? ''}'.trim(),
      stage: stage,
      rewardAmount: _finiteAmount(data['rewardAmount']),
      createdAt: _dateTime(data['createdAt']),
      qualifiedAt: _dateTime(data['qualifiedAt']),
      rewardedAt: _dateTime(data['rewardedAt']),
    );
  }

  final String id;
  final RiderReferralStage stage;
  final double rewardAmount;
  final DateTime? createdAt;
  final DateTime? qualifiedAt;
  final DateTime? rewardedAt;

  bool get credited => stage == RiderReferralStage.credited;

  String get statusLabel => switch (stage) {
        RiderReferralStage.invited => 'Invitation pending',
        RiderReferralStage.signedUp => 'Signed up - awaiting qualification',
        RiderReferralStage.qualified => 'Qualification verified',
        RiderReferralStage.credited => 'Credited to Roth Wallet',
        RiderReferralStage.review => 'Review required',
        RiderReferralStage.rejected => 'Not eligible',
        RiderReferralStage.unknown => 'Status updating',
      };

  String get amountLabel => switch (stage) {
        RiderReferralStage.credited => '+${formatRoth(rewardAmount)} Roth',
        RiderReferralStage.invited ||
        RiderReferralStage.signedUp ||
        RiderReferralStage.qualified =>
          '${formatRoth(rewardAmount)} Roth pending',
        RiderReferralStage.review => 'Credit on hold',
        RiderReferralStage.rejected => 'Not credited',
        RiderReferralStage.unknown => 'Awaiting verification',
      };
}

class RiderReferralDashboard {
  const RiderReferralDashboard({
    required this.code,
    required this.link,
    required this.referrals,
  });

  factory RiderReferralDashboard.fromMap(Map<String, dynamic> data) =>
      RiderReferralDashboard(
        code: '${data['referralCode'] ?? ''}'.trim(),
        link: '${data['referralLink'] ?? ''}'.trim(),
        referrals: (data['referrals'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (item) =>
                  RiderReferralRecord.fromMap(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
      );

  final String code;
  final String link;
  final List<RiderReferralRecord> referrals;

  int get creditedCount => referrals.where((item) => item.credited).length;
  int get pendingCount => referrals
      .where(
        (item) =>
            item.stage != RiderReferralStage.credited &&
            item.stage != RiderReferralStage.rejected,
      )
      .length;
}

class RiderRothWalletDashboard {
  const RiderRothWalletDashboard({
    required this.wallet,
    required this.transactions,
    required this.referrals,
    this.nextPageToken,
  });

  final RiderRothWallet wallet;
  final List<RiderRothTransaction> transactions;
  final RiderReferralDashboard referrals;
  final String? nextPageToken;
}

class RiderRothReferralView extends StatefulWidget {
  const RiderRothReferralView({super.key, this.dataSource});

  final RiderRothWalletDataSource? dataSource;

  @override
  State<RiderRothReferralView> createState() => _RiderRothReferralViewState();
}

class _RiderRothReferralViewState extends State<RiderRothReferralView> {
  late final RiderRothWalletDataSource _dataSource;
  RiderRothWalletDashboard? _dashboard;
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? RiderRothWalletRepository();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        _dataSource.loadTransactions(),
        _dataSource.loadReferrals(),
      ]);
      final page = results[0] as RiderRothTransactionPage;
      final referrals = results[1] as RiderReferralDashboard;
      if (!mounted) return;
      setState(() {
        _dashboard = RiderRothWalletDashboard(
          wallet: page.wallet,
          transactions: page.transactions,
          referrals: referrals,
          nextPageToken: page.nextPageToken,
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final current = _dashboard;
    final token = current?.nextPageToken;
    if (current == null || token == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _dataSource.loadTransactions(pageToken: token);
      if (!mounted) return;
      final known = current.transactions.map((item) => item.id).toSet();
      setState(() {
        _dashboard = RiderRothWalletDashboard(
          wallet: page.wallet,
          transactions: [
            ...current.transactions,
            ...page.transactions.where((item) => known.add(item.id)),
          ],
          referrals: current.referrals,
          nextPageToken: page.nextPageToken,
        );
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('More Roth activity is unavailable right now.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Referral link copied.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RiderPalette.background,
      appBar: AppBar(
        title: const Text('Roth Wallet'),
        backgroundColor: RiderPalette.background,
      ),
      body: _loading && _dashboard == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _dashboard == null
              ? _WalletFailure(onRetry: _load)
              : _WalletContent(
                  dashboard: _dashboard!,
                  loadingMore: _loadingMore,
                  onRefresh: _load,
                  onLoadMore: _loadMore,
                  onCopyReferral: _copy,
                ),
    );
  }
}

class RiderRothWalletSummaryCard extends StatefulWidget {
  const RiderRothWalletSummaryCard({super.key, this.dataSource, this.onOpen});

  final RiderRothWalletDataSource? dataSource;
  final VoidCallback? onOpen;

  @override
  State<RiderRothWalletSummaryCard> createState() =>
      _RiderRothWalletSummaryCardState();
}

class _RiderRothWalletSummaryCardState
    extends State<RiderRothWalletSummaryCard> {
  late final RiderRothWalletDataSource _dataSource;
  late Future<RiderRothWallet> _wallet;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? RiderRothWalletRepository();
    _wallet = _dataSource.loadWallet();
  }

  void _open() {
    if (widget.onOpen != null) {
      widget.onOpen!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RiderRothReferralView(dataSource: _dataSource),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RiderRothWallet>(
      future: _wallet,
      builder: (context, snapshot) {
        final wallet = snapshot.data;
        final amount = wallet == null
            ? snapshot.hasError
                ? 'Unavailable'
                : 'Loading'
            : '${formatRoth(wallet.balance)} Roth';
        return Semantics(
          label: 'Roth Wallet. $amount available. Open Roth Wallet.',
          button: true,
          excludeSemantics: true,
          child: RiderGlassSurface(
            onTap: _open,
            edgeColor: RiderPalette.purple,
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: RiderPalette.purple.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.diamond_outlined,
                    color: RiderPalette.purple,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Roth Wallet',
                        style: TextStyle(
                          color: RiderPalette.paper,
                          fontFamily: RiderTypography.heading,
                          fontSize: 19,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Separate from cash earnings',
                        style: TextStyle(
                          color: RiderPalette.muted,
                          fontFamily: RiderTypography.body,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amount,
                      style: TextStyle(
                        color: wallet == null
                            ? RiderPalette.muted
                            : RiderPalette.purple,
                        fontFamily: RiderTypography.mono,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: RiderPalette.muted,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WalletContent extends StatelessWidget {
  const _WalletContent({
    required this.dashboard,
    required this.loadingMore,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onCopyReferral,
  });

  final RiderRothWalletDashboard dashboard;
  final bool loadingMore;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final ValueChanged<String> onCopyReferral;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: RiderPalette.blue,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _RothBalanceCard(wallet: dashboard.wallet),
          const SizedBox(height: 22),
          const _SectionTitle('Recent Roth activity'),
          const SizedBox(height: 10),
          if (dashboard.transactions.isEmpty)
            const RiderGlassSurface(
              child: Text(
                'No Roth activity yet. Verified rewards and approved Roth movements will appear here.',
                style: TextStyle(color: RiderPalette.muted, height: 1.45),
              ),
            )
          else ...[
            for (final transaction in dashboard.transactions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RothTransactionRow(transaction: transaction),
              ),
            if (dashboard.nextPageToken != null)
              OutlinedButton.icon(
                onPressed: loadingMore ? null : onLoadMore,
                icon: loadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: const Text('Load more activity'),
              ),
          ],
          const SizedBox(height: 22),
          const _SectionTitle('Earn Roth'),
          const SizedBox(height: 10),
          _ReferralInviteCard(
            dashboard: dashboard.referrals,
            onCopy: onCopyReferral,
          ),
          const SizedBox(height: 12),
          const _ReferralFlowCard(),
          const SizedBox(height: 22),
          const _SectionTitle('Referral history'),
          const SizedBox(height: 10),
          if (dashboard.referrals.referrals.isEmpty)
            const RiderGlassSurface(
              child: Text(
                'No referrals yet. Share your code to start.',
                style: TextStyle(color: RiderPalette.muted),
              ),
            )
          else
            for (final referral in dashboard.referrals.referrals)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ReferralRow(referral: referral),
              ),
        ],
      ),
    );
  }
}

class _RothBalanceCard extends StatelessWidget {
  const _RothBalanceCard({required this.wallet});

  final RiderRothWallet wallet;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '${formatRoth(wallet.balance)} Roth available.',
        child: RiderGlassSurface(
          edgeColor: RiderPalette.purple,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.diamond_outlined, color: RiderPalette.purple),
                  SizedBox(width: 9),
                  Text(
                    'Available Roth',
                    style: TextStyle(
                      color: RiderPalette.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${formatRoth(wallet.balance)} Roth',
                style: const TextStyle(
                  color: RiderPalette.paper,
                  fontFamily: RiderTypography.mono,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Roth is separate from cash earnings. The balance and activity below come from the canonical CIRCUM Roth ledger.',
                style: TextStyle(color: RiderPalette.muted, height: 1.45),
              ),
              if (wallet.frozen) ...[
                const SizedBox(height: 12),
                const Text(
                  'This Roth Wallet is currently frozen. Activity remains visible.',
                  style: TextStyle(color: RiderPalette.amber),
                ),
              ],
            ],
          ),
        ),
      );
}

class _RothTransactionRow extends StatelessWidget {
  const _RothTransactionRow({required this.transaction});

  final RiderRothTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final color = transaction.status == 'completed'
        ? transaction.credit
            ? RiderPalette.green
            : RiderPalette.paper
        : RiderPalette.amber;
    return Semantics(
      label:
          '${transaction.title}. ${transaction.amountLabel}. ${transaction.statusLabel}.',
      child: RiderGlassSurface(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                transaction.credit
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                color: color,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    style: const TextStyle(
                      color: RiderPalette.paper,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _transactionDetail(transaction),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RiderPalette.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  transaction.amountLabel,
                  style: TextStyle(
                    color: color,
                    fontFamily: RiderTypography.mono,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.statusLabel,
                  style: const TextStyle(
                    color: RiderPalette.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferralInviteCard extends StatelessWidget {
  const _ReferralInviteCard({required this.dashboard, required this.onCopy});

  final RiderReferralDashboard dashboard;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) => RiderGlassSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invite through Roth',
              style: TextStyle(
                color: RiderPalette.paper,
                fontFamily: RiderTypography.heading,
                fontSize: 21,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share your referral link. Rewards are credited automatically only after CIRCUM verifies a qualifying activity.',
              style: TextStyle(color: RiderPalette.muted, height: 1.45),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ReferralMetric(
                  label: 'Pending',
                  value: '${dashboard.pendingCount}',
                ),
                _ReferralMetric(
                  label: 'Credited',
                  value: '${dashboard.creditedCount}',
                ),
              ],
            ),
            if (dashboard.code.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Referral code',
                style: TextStyle(
                  color: RiderPalette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              SelectableText(
                dashboard.code,
                style: const TextStyle(
                  color: RiderPalette.paper,
                  fontFamily: RiderTypography.mono,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (dashboard.link.isNotEmpty)
              RiderPrimaryButton(
                label: 'Copy referral link',
                icon: Icons.copy_rounded,
                onPressed: () => onCopy(dashboard.link),
              )
            else
              const Text(
                'Referral code is not available yet.',
                style: TextStyle(color: RiderPalette.amber),
              ),
          ],
        ),
      );
}

class _ReferralFlowCard extends StatelessWidget {
  const _ReferralFlowCard();

  @override
  Widget build(BuildContext context) => const RiderGlassSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How referral rewards move',
              style: TextStyle(
                color: RiderPalette.paper,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 16),
            _ReferralFlowStep(
              number: '1',
              title: 'Invite linked',
              detail: 'Your secure referral code is attached to the account.',
            ),
            _ReferralFlowStep(
              number: '2',
              title: 'Activity verified',
              detail:
                  'The backend verifies an approved qualifying activity. The client cannot approve it.',
            ),
            _ReferralFlowStep(
              number: '3',
              title: 'Roth credited',
              detail:
                  'One deterministic ledger transaction updates the canonical Roth balance exactly once.',
              last: true,
            ),
            SizedBox(height: 12),
            Text(
              'Pending referral value is not part of your available Roth until the wallet ledger records the credit.',
              style: TextStyle(color: RiderPalette.muted, height: 1.4),
            ),
          ],
        ),
      );
}

class _ReferralFlowStep extends StatelessWidget {
  const _ReferralFlowStep({
    required this.number,
    required this.title,
    required this.detail,
    this.last = false,
  });

  final String number;
  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: RiderPalette.blue,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!last)
                Container(width: 1, height: 42, color: RiderPalette.blue),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: RiderPalette.paper,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: const TextStyle(
                        color: RiderPalette.muted, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}

class _ReferralMetric extends StatelessWidget {
  const _ReferralMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 112),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: RiderPalette.muted, fontSize: 11),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: RiderPalette.paper,
                fontFamily: RiderTypography.mono,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _ReferralRow extends StatelessWidget {
  const _ReferralRow({required this.referral});

  final RiderReferralRecord referral;

  @override
  Widget build(BuildContext context) {
    final color = switch (referral.stage) {
      RiderReferralStage.credited => RiderPalette.green,
      RiderReferralStage.rejected => RiderPalette.red,
      RiderReferralStage.review => RiderPalette.amber,
      _ => RiderPalette.blue,
    };
    return RiderGlassSurface(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.group_add_outlined, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  referral.statusLabel,
                  style: const TextStyle(
                    color: RiderPalette.paper,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_referralDate(referral) case final date?) ...[
                  const SizedBox(height: 3),
                  Text(
                    date,
                    style: const TextStyle(
                      color: RiderPalette.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            referral.amountLabel,
            style: TextStyle(
              color: color,
              fontFamily: RiderTypography.mono,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.value);

  final String value;

  @override
  Widget build(BuildContext context) => Text(
        value,
        style: const TextStyle(
          color: RiderPalette.paper,
          fontFamily: RiderTypography.heading,
          fontSize: 20,
        ),
      );
}

class _WalletFailure extends StatelessWidget {
  const _WalletFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: RiderEmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Roth Wallet unavailable',
            message: 'Your Roth is safe. Check your connection and try again.',
            actionLabel: 'Retry',
            onAction: onRetry,
          ),
        ),
      );
}

double _finiteAmount(Object? value) {
  final amount = value is num ? value.toDouble() : double.tryParse('$value');
  return amount != null && amount.isFinite ? amount : 0;
}

String formatRoth(double value) =>
    value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

String? _optionalText(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}

DateTime? _dateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    final seconds = map['_seconds'] ?? map['seconds'];
    if (seconds is num) {
      return DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000);
    }
  }
  return null;
}

String _transactionDetail(RiderRothTransaction transaction) {
  final date = transaction.createdAt;
  if (date == null) return transaction.description;
  return '${transaction.description} - ${DateFormat('d MMM yyyy, HH:mm').format(date.toLocal())}';
}

String? _referralDate(RiderReferralRecord referral) {
  final date =
      referral.rewardedAt ?? referral.qualifiedAt ?? referral.createdAt;
  if (date == null) return null;
  return DateFormat('d MMM yyyy').format(date.toLocal());
}
