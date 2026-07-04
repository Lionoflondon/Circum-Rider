import 'package:circum_rider/app/rider_jobs/rider_points_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RiderPointsRules', () {
    test('uses the approved points table', () {
      expect(RiderPointsRules.points[RiderJobCategory.standard], 1);
      expect(RiderPointsRules.points[RiderJobCategory.marketplace], 2);
      expect(RiderPointsRules.points[RiderJobCategory.business], 3);
      expect(RiderPointsRules.points[RiderJobCategory.vanguard], 4);
      expect(RiderPointsRules.points[RiderJobCategory.heavyDuty], 4);
      expect(RiderPointsRules.points[RiderJobCategory.gift], 5);
      expect(RiderPointsRules.points[RiderJobCategory.scheduled], 5);
      expect(RiderPointsRules.points[RiderJobCategory.healthPlus], 6);
    });

    test('category priority favours Health+ over other flags', () {
      final result = RiderPointsRules.resolve({
        'isHealthPlus': true,
        'isGift': true,
        'isScheduled': true,
        'requiresVanguard': true,
        'isBusiness': true,
      });

      expect(result.category, RiderJobCategory.healthPlus);
      expect(result.points, 6);
      expect(result.label, 'Health+');
      expect(result.usedFallback, isFalse);
    });

    test('missing category falls back to Standard +1', () {
      final result = RiderPointsRules.resolve({});

      expect(result.category, RiderJobCategory.standard);
      expect(result.points, 1);
      expect(result.label, 'Standard');
      expect(result.usedFallback, isTrue);
    });
  });
}
