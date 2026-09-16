import 'package:cloud_functions/cloud_functions.dart';

import '../models/earnings.m.dart';

class EarningsRepo {
  Future<EarningsModel> fetchEarnings({
    required String riderId,
  }) async {
    try {
      final response =
          await FirebaseFunctions.instanceFor(region: 'us-central1')
              .httpsCallable('getRiderEarningsSummary')
              .call(const <String, dynamic>{});
      final summary = Map<String, dynamic>.from(response.data as Map);
      final totals = Map<String, dynamic>.from(
        (summary['totals'] as Map?) ?? const <String, dynamic>{},
      );
      final totalEarned = totals.entries
          .where((entry) => !{
                'adjustment_debit',
                'payout_reserved',
                'refund',
                'reversal',
              }.contains(entry.key))
          .fold<double>(0, (sum, entry) => sum + _number(entry.value));
      return EarningsModel(
        accountBalance: _number(summary['storedAvailable']),
        totalAmountEarned: totalEarned,
        totalTrips: _integer(summary['activityCount']),
        weeklyEarnings: const <String, double>{},
      );
    } catch (_) {
      throw Exception("Something went wrong");
    }
  }

  static double _number(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

  static int _integer(Object? value) =>
      int.tryParse('${value ?? 0}') ?? _number(value).round();
}
