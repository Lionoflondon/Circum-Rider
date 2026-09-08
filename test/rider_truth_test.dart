import 'package:circum_rider/app/rider_design/rider_ui.dart';
import 'package:flutter/material.dart';
import 'package:circum_rider/app/rider_jobs/rider_points_rules.dart';
import 'package:circum_rider/app/rider_truth/rider_truth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('missing rank renders unavailable without a fabricated badge',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: RiderRankProgress(
                rank: 'Rank unavailable', trustPoints: 999))));
    expect(find.textContaining('Rank unavailable'), findsOneWidget);
    expect(find.text('AGENT'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  test('missing canonical rank is unavailable rather than inferred from trust',
      () {
    final value = RiderRankSnapshot.from({'trustPoints': 0, 'rank': 'Veteran'});
    expect(value?.rank, 'Rank unavailable');
    expect(value?.trustPoints, 0);
  });

  test('canonical rank is displayed without client recalculation', () {
    final value =
        RiderRankSnapshot.from({'trustPoints': 0, 'riderRank': 'Sentinel'});
    expect(value?.rank, 'Sentinel');
  });

  test('missing trust remains unavailable', () {
    expect(RiderRankSnapshot.from({'rank': 'Veteran'}), isNull);
  });

  test('explicit manual override remains labelled', () {
    final value = RiderRankSnapshot.from({
      'trustPoints': 0,
      'rank': 'Veteran',
      'rankOverride': true,
      'rankOverrideReason': 'Founding Rider'
    });
    expect(value?.rank, 'Veteran');
    expect(value?.overrideReason, 'Founding Rider');
  });

  test('highest applicable trust award wins once', () {
    final value = RiderPointsRules.resolve(
        {'isBusiness': true, 'isGift': true, 'isHealthPlus': true});
    expect(value.points, 6);
    expect(value.category, RiderJobCategory.healthPlus);
  });

  test('earnings summary requires backend totals', () {
    expect(RiderEarningsSummary.from({}), isNull);
    final value = RiderEarningsSummary.from(
        {'availableBalance': 12.5, 'pendingBalance': 4, 'tipsTotal': 2});
    expect(value?.available, 12.5);
    expect(value?.tips, 2);
  });

  test('bicycle and motor vehicles use truthful registration rules', () {
    final bike = RiderVehicleSnapshot.from({'type': 'Bicycle'}, primary: true);
    final van = RiderVehicleSnapshot.from({
      'type': 'Van',
      'registration': 'AB12 CDE',
      'verificationStatus': 'approved'
    }, primary: false);
    expect(bike.registrationRequired, isFalse);
    expect(van.registration, 'AB12 CDE');
    expect(van.status, 'VERIFIED');
  });
}
