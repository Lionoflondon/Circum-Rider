import 'package:flutter_test/flutter_test.dart';
import 'package:circum_rider/app/notifications/rider_notification_entity_view.dart';

void main() {
  test('unassigned job targets retain exact offer identity for authorized feed',
      () {
    final target = RiderNotificationTarget.fromDestination(
        {'route': 'jobs', 'deliveryId': 'job-1'});
    expect(target?.id, 'job-1');
    expect(target?.isOffer, true);
  });
  test(
      'entity ownership rejects conflicting delivery aliases and forged unrelated UID',
      () {
    expect(riderOwnsNotificationEntity({'riderId': 'mine'}, 'mine'), true);
    expect(riderOwnsNotificationEntity({'uid': 'mine'}, 'mine'), false);
    expect(
        riderOwnsNotificationEntity(
            {'riderId': 'mine', 'assignedRiderId': 'other'}, 'mine'),
        false);
    expect(
        riderOwnsNotificationEntity({'uid': 'mine', 'riderId': 'other'}, 'mine',
            collection: 'payoutRequests'),
        false);
    expect(
        riderOwnsNotificationEntity({}, 'mine',
            collection: 'riderApplications', documentId: 'other'),
        false);
  });
  test('missing and path-based entity targets fall back safely', () {
    expect(RiderNotificationTarget.fromDestination({'route': 'jobs'}), isNull);
    expect(
        RiderNotificationTarget.fromDestination(
            {'route': 'payout', 'requestId': 'other/path'}),
        isNull);
  });
}
