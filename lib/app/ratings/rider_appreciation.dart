import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../rider_design/rider_ui.dart';

class RiderAppreciationService {
  RiderAppreciationService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> load({int limit = 20, int? beforeMillis}) async {
    final response =
        await _functions.httpsCallable('getRiderAppreciation').call({
      'limit': limit,
      if (beforeMillis != null) 'beforeMillis': beforeMillis,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }
}

class RiderAppreciationListener extends StatefulWidget {
  const RiderAppreciationListener({super.key, required this.child});

  final Widget child;

  @override
  State<RiderAppreciationListener> createState() =>
      _RiderAppreciationListenerState();
}

class _RiderAppreciationListenerState extends State<RiderAppreciationListener> {
  Timer? _timer;
  final _service = RiderAppreciationService();
  var _presenting = false;
  var _lastSeenMillis = 0;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  Future<void> _listen() async {
    final prefs = await SharedPreferences.getInstance();
    _lastSeenMillis = prefs.getInt('lastSeenRiderRatingAt') ?? 0;
    await _refresh();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_presenting || !mounted) return;
    Map<String, dynamic> projection;
    try {
      projection = await _service.load(limit: 1);
    } catch (_) {
      return;
    }
    final praise = (projection['recentPraise'] as List? ?? const []);
    if (praise.isEmpty) return;
    final latest = Map<String, dynamic>.from(praise.first as Map);
    final createdAt = _millis(latest['createdAt']);
    if (createdAt <= _lastSeenMillis) return;
    _presenting = true;
    _lastSeenMillis = createdAt;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSeenRiderRatingAt', createdAt);
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: RiderAppreciationView(
            ratingId: 'latest',
            rating: latest,
            tip: ((projection['tips'] as List? ?? const []).isEmpty)
                ? const {}
                : Map<String, dynamic>.from(
                    (projection['tips'] as List).first as Map,
                  ),
            earnings: Map<String, dynamic>.from(
              projection['summary'] as Map? ?? const {},
            ),
          ),
        ),
      ),
    );
    _presenting = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  static int _millis(Object? value) {
    try {
      final dynamic candidate = value;
      return candidate.millisecondsSinceEpoch as int;
    } catch (_) {
      return DateTime.tryParse('$value')?.millisecondsSinceEpoch ?? 0;
    }
  }
}

class RiderAppreciationView extends StatelessWidget {
  const RiderAppreciationView({
    super.key,
    required this.ratingId,
    required this.rating,
    this.tip = const {},
    this.earnings = const {},
  });

  final String ratingId;
  final Map<String, dynamic> rating;
  final Map<String, dynamic> tip;
  final Map<String, dynamic> earnings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RiderPalette.background,
      body: SafeArea(
        child: _AppreciationSurface(
          rating: rating,
          tip: tip,
          earnings: earnings,
          onContinue: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

class _AppreciationSurface extends StatelessWidget {
  const _AppreciationSurface({
    required this.rating,
    required this.tip,
    required this.earnings,
    required this.onContinue,
  });

  final Map<String, dynamic> rating;
  final Map<String, dynamic> tip;
  final Map<String, dynamic> earnings;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final stars = (rating['starRating'] as num? ?? rating['stars'] as num? ?? 0)
        .toInt()
        .clamp(0, 5);
    final feedback =
        '${rating['feedbackText'] ?? rating['comment'] ?? ''}'.trim();
    final amount = tip['status'] == 'succeeded'
        ? (tip['amount'] as num? ?? 0).toDouble()
        : 0.0;
    final fare = (earnings['lastDeliveryFare'] as num? ??
            earnings['latestDeliveryAmount'] as num? ??
            0)
        .toDouble();
    final today = (earnings['todayEarnings'] as num? ??
            earnings['availableToday'] as num? ??
            0)
        .toDouble();
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: RiderPalette.background.withValues(alpha: .94),
          foregroundColor: Colors.white,
          title: const Text('Delivery appreciation'),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          sliver: SliverList.list(
            children: [
              RiderGlassSurface(
                borderColor: RiderPalette.green.withValues(alpha: .28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 340),
                      curve: Curves.easeOutBack,
                      tween: Tween(begin: .5, end: 1),
                      builder: (_, value, child) =>
                          Transform.scale(scale: value, child: child),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: RiderPalette.green,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "You made someone's day.",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'A Sender appreciated your delivery.',
                            style: TextStyle(color: RiderPalette.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              RiderGlassSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ref ${rating['deliveryId'] ?? 'Delivery'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _time(rating['createdAt']),
                          style: const TextStyle(
                            color: RiderPalette.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (index) => Icon(
                            Icons.star_rounded,
                            color: index < stars
                                ? const Color(0xFFFBBF24)
                                : Colors.white.withValues(alpha: .18),
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _title(stars),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (feedback.isNotEmpty) ...[
                      const SizedBox(height: 15),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          '“$feedback”',
                          style: const TextStyle(
                            color: RiderPalette.muted,
                            fontSize: 15,
                            height: 1.45,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (amount > 0) ...[
                const SizedBox(height: 16),
                RiderGlassSurface(
                  borderColor: RiderPalette.green.withValues(alpha: .28),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_circle_rounded,
                        color: RiderPalette.green,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Tip received',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 500),
                        tween: Tween(begin: 0, end: amount),
                        builder: (_, value, __) => Text(
                          '+£${value.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: RiderPalette.green,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              RiderGlassSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wallet',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _row('Delivery', fare),
                    _row('Tip', amount, positive: amount > 0),
                    Divider(color: Colors.white.withValues(alpha: .08)),
                    _row("Today's Earnings", today, strong: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              RiderGlassSurface(
                child: Row(
                  children: [
                    Expanded(
                      child: _stat(
                        'Average Rating',
                        _number(
                          earnings['averageRating'] ??
                              rating['riderAverageRating'],
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 42,
                      color: Colors.white.withValues(alpha: .08),
                    ),
                    Expanded(
                      child: _stat(
                        'Lifetime Ratings',
                        '${earnings['totalRatings'] ?? '—'}',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 42,
                      color: Colors.white.withValues(alpha: .08),
                    ),
                    Expanded(
                      child: _stat('Tips Today', _money(earnings['tipsToday'])),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: RiderPalette.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(
    String label,
    double amount, {
    bool positive = false,
    bool strong = false,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: strong ? Colors.white : RiderPalette.muted,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            Text(
              '${positive ? '+' : ''}£${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: positive ? RiderPalette.green : Colors.white,
                fontFamily: 'monospace',
                fontWeight:
                    strong || positive ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _stat(String label, String value) => Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: RiderPalette.muted, fontSize: 10.5),
          ),
        ],
      );

  static String _title(int stars) => switch (stars) {
        5 => 'Outstanding',
        4 => 'Great',
        3 => 'Good',
        2 => 'Needs Improvement',
        1 => 'Poor Experience',
        _ => 'Rating received',
      };
  static String _time(Object? value) {
    DateTime? date;
    try {
      final dynamic timestamp = value;
      date = (timestamp.toDate() as DateTime).toLocal();
    } catch (_) {
      date = DateTime.tryParse('$value')?.toLocal();
    }
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _number(Object? value) =>
      value is num && value > 0 ? value.toStringAsFixed(1) : '—';
  static String _money(Object? value) =>
      value is num ? '£${value.toStringAsFixed(2)}' : '—';
}

class RiderRatingsHistoryView extends StatefulWidget {
  const RiderRatingsHistoryView({super.key, required this.riderId});

  final String riderId;

  @override
  State<RiderRatingsHistoryView> createState() =>
      _RiderRatingsHistoryViewState();
}

class _RiderRatingsHistoryViewState extends State<RiderRatingsHistoryView> {
  final _service = RiderAppreciationService();
  late Future<Map<String, dynamic>> _projection = _service.load(limit: 30);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: RiderPalette.background,
        appBar: AppBar(
          backgroundColor: RiderPalette.background,
          foregroundColor: Colors.white,
          title: const Text('Ratings & Tips'),
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _projection,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return RiderEmptyState(
                icon: Icons.refresh_rounded,
                title: 'Appreciation unavailable',
                message: 'Check your connection and try again.',
                actionLabel: 'Retry',
                onAction: () =>
                    setState(() => _projection = _service.load(limit: 30)),
              );
            }
            final data = snapshot.data ?? const <String, dynamic>{};
            final summary = Map<String, dynamic>.from(
              data['summary'] as Map? ?? const {},
            );
            final ratings = (data['recentPraise'] as List? ?? const [])
                .map((value) => Map<String, dynamic>.from(value as Map))
                .toList();
            final tips = (data['tips'] as List? ?? const [])
                .map((value) => Map<String, dynamic>.from(value as Map))
                .toList();
            final distribution =
                (summary['distribution'] as List? ?? const [0, 0, 0, 0, 0])
                    .map((value) => (value as num?)?.toInt() ?? 0)
                    .toList();
            final totalRatings =
                (summary['totalRatings'] as num?)?.toInt() ?? 0;
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                RiderGlassSurface(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _historyMetric(
                        'Lifetime Rating',
                        _decimal(summary['averageRating']),
                      ),
                      _historyMetric('Total Ratings', '$totalRatings'),
                      _historyMetric(
                        'Total Tips',
                        _currency(summary['lifetimeTips']),
                      ),
                      _historyMetric(
                        'Tips Today',
                        _currency(summary['tipsToday']),
                      ),
                      _historyMetric(
                        'Tips This Week',
                        _currency(summary['tipsThisWeek']),
                      ),
                      _historyMetric(
                        'Average Tip',
                        _currency(summary['averageTip']),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                RiderGlassSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rating Distribution',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (var star = 5; star >= 1; star--)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 34,
                                child: Text(
                                  '$star ★',
                                  style:
                                      const TextStyle(color: Color(0xFFFBBF24)),
                                ),
                              ),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: totalRatings == 0
                                      ? 0
                                      : distribution[star - 1] / totalRatings,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(6),
                                  color: const Color(0xFFFBBF24),
                                  backgroundColor: Colors.white.withValues(
                                    alpha: .08,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 34,
                                child: Text(
                                  '${distribution[star - 1]}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: RiderPalette.muted,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Recent Reviews',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (ratings.isEmpty)
                  const RiderEmptyState(
                    icon: Icons.star_outline_rounded,
                    title: 'No ratings yet',
                    message:
                        'Sender appreciation will appear here after completed deliveries.',
                  )
                else
                  ...ratings.map(
                    (value) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RiderGlassSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              List.filled(
                                (value['stars'] as num? ?? 0)
                                    .toInt()
                                    .clamp(0, 5),
                                '★',
                              ).join(),
                              style: const TextStyle(
                                color: Color(0xFFFBBF24),
                                fontSize: 18,
                              ),
                            ),
                            if ('${value['comment'] ?? ''}'
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(height: 7),
                              Text(
                                '“${value['comment']}”',
                                style: const TextStyle(
                                  color: RiderPalette.muted,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            if ((value['compliments'] as List? ?? const [])
                                .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: (value['compliments'] as List)
                                    .map((tag) => Chip(label: Text('$tag')))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Tip History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (tips.isEmpty)
                  const RiderEmptyState(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'No tips yet',
                    message: 'Tips from completed deliveries appear here.',
                  )
                else
                  ...tips.map(
                    (value) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: value['status'] == 'reversed'
                            ? const Color(0x1FF87171)
                            : const Color(0x1F34D399),
                        child: Icon(
                          value['status'] == 'reversed'
                              ? Icons.undo_rounded
                              : Icons.add_rounded,
                          color: value['status'] == 'reversed'
                              ? const Color(0xFFF87171)
                              : RiderPalette.green,
                        ),
                      ),
                      title: Text(
                        _currency(value['amount']),
                        style: const TextStyle(
                          color: RiderPalette.green,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                        ),
                      ),
                      subtitle: Text(
                        'Ref ${value['deliveryId']} · ${value['payoutStatus']}',
                        style: const TextStyle(
                          color: RiderPalette.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );

  static Widget _historyMetric(String label, String value) => SizedBox(
        width: 135,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: RiderPalette.muted, fontSize: 11),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );
  static String _decimal(Object? value) =>
      value is num && value > 0 ? value.toStringAsFixed(2) : '—';
  static String _currency(Object? value) =>
      value is num ? '£${value.toStringAsFixed(2)}' : '—';
}
