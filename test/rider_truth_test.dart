import 'package:circum_rider/app/rider_jobs/rider_points_rules.dart';
import 'package:circum_rider/app/rider_truth/rider_truth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('zero trust resolves to Agent and never Veteran', () {
    final value = RiderRankSnapshot.from({'trustPoints': 0, 'rank': 'Veteran'});
    expect(value?.rank, 'Agent');
    expect(value?.trustPoints, 0);
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

  test('legacy trust projection remains authoritative when canonical is zero',
      () {
    final value = RiderRankSnapshot.from({
      'trustPoints': 0,
      'riderTrustPoints': 3,
    });

    expect(value?.trustPoints, 3);
    expect(value?.rank, 'Agent');
  });

  test('admin assignment metadata preserves assigned Veteran truth', () {
    final value = RiderRankSnapshot.from({
      'trustPoints': 0,
      'riderTrustPoints': 3,
      'riderRank': 'Veteran',
      'rankUpdatedBy': 'admin-1',
      'rankReason': 'Assigned Veteran',
    });

    expect(value?.trustPoints, 3);
    expect(value?.rank, 'Veteran');
    expect(value?.overrideReason, 'Assigned Veteran');
  });

  test('Rider authority assignment and highest trust projection win stale data',
      () {
    final merged = mergeRiderAuthorityData(
      {
        'riderTrustPoints': 3,
        'riderRank': 'Veteran',
        'rankUpdatedBy': 'admin-1',
        'rankReason': 'Assigned Veteran',
      },
      {
        'trustPoints': 0,
        'riderRank': 'Agent',
        'rankUpdatedBy': 'legacy-admin',
        'rankReason': 'test',
      },
    );
    final value = RiderRankSnapshot.from(merged);

    expect(value?.trustPoints, 3);
    expect(value?.rank, 'Veteran');
    expect(value?.overrideReason, 'Assigned Veteran');
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
