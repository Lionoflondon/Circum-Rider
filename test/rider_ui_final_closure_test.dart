import 'dart:io';

import 'package:circum_rider/app/rider_truth/rider_truth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy valid Riders are never signed out because of account age', () {
    final source =
        File('lib/app/authentication/bloc/auth_bloc.dart').readAsStringSync();
    expect(source, isNot(contains("DateTime.parse('2024-05-15')")));
    expect(source, isNot(contains('authChangeDate.isAfter')));
  });

  test('assigned rank is distinct from earned progression', () {
    final assigned = RiderRankSnapshot.from(const {
      'trustPoints': 3,
      'rank': 'Veteran',
      'rankOverride': true,
      'rankOverrideReason': 'Founding Rider',
    });
    expect(assigned?.rank, 'Veteran');
    expect(assigned?.isAssigned, isTrue);
    expect(RiderRankSnapshot.rankForTrust(3), 'Agent');

    final dashboard = File('lib/app/rider_shell/rider_dashboard_view.dart')
        .readAsStringSync();
    expect(dashboard, contains("assignedRank ? 'Assigned rank' : 'Top rank'"));
  });

  test('schedule rank and timestamp remain canonical', () {
    final source =
        File('lib/app/schedule/rider_schedule_view.dart').readAsStringSync();
    expect(source, contains('RiderRankSnapshot.from'));
    expect(source, contains('riderRank: rank'));
    expect(source, contains("return DateTime.tryParse('\${value ?? ''}')"));
    expect(source, isNot(contains('value is Timestamp ? value.toDate() : DateTime.now()')));
    expect(source, contains("if (!scheduleValid) return 'Schedule unavailable'"));
  });

  test('earnings are ordered and cursor paginated by the server', () {
    final source =
        File('lib/app/account/view/earnings.dart').readAsStringSync();
    expect(source, contains(".orderBy('createdAt', descending: true)"));
    expect(source,
        contains('orderBy(FieldPath.documentId, descending: true)'));
    expect(source, contains('startAfterDocument('));
    expect(source, contains('_transactionDocs.last'));
    expect(source, contains('Load older activity'));
  });

  test('restoration failure blocks availability and offers recovery', () {
    final state = File('lib/app/home/bloc/home_state.dart').readAsStringSync();
    final dashboard = File('lib/app/rider_shell/rider_dashboard_view.dart')
        .readAsStringSync();
    expect(state, contains('ActiveDeliveryRestoreStatus'));
    expect(dashboard, contains('Unable to restore active job'));
    expect(dashboard, contains('Retry active job restoration'));
    expect(dashboard, contains('!restoreFailed'));
  });

  test('central action communicates Rider availability', () {
    final source =
        File('lib/app/bottom_nav/view/app_nav.dart').readAsStringSync();
    expect(source, contains("'Availability'"));
    expect(source, contains('Icons.power_settings_new_rounded'));
    expect(source, isNot(contains('Icons.add_rounded')));
  });
}
