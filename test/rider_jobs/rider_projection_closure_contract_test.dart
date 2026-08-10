import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reachable Rider source never reads full delivery request documents',
      () {
    final offenders = <String>[];
    for (final file
        in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (file.readAsStringSync().contains("collection('deliveryRequests')")) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('all Rider job surfaces consume the shared bounded projection', () {
    final schedule =
        File('lib/app/schedule/rider_schedule_view.dart').readAsStringSync();
    final dashboard = File('lib/app/rider_shell/rider_dashboard_view.dart')
        .readAsStringSync();
    final accepted = File('lib/app/rider_jobs/rider_job_offer_screen.dart')
        .readAsStringSync();
    final tracking =
        File('lib/app/tracking/rider_live_tracking_controller.dart')
            .readAsStringSync();

    expect(schedule, contains('RiderJobProjectionService'));
    expect(dashboard, contains('RiderJobProjectionService'));
    expect(accepted, contains('_projectionService!.load()'));
    expect(accepted, contains('delivery: live'));
    expect(tracking, isNot(contains('DocumentSnapshot')));
  });
}
