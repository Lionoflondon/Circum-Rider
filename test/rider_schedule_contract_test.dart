import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonical Rider Schedule', () {
    final schedule =
        File('lib/app/schedule/rider_schedule_view.dart').readAsStringSync();
    final nav = File('lib/app/bottom_nav/view/app_nav.dart').readAsStringSync();
    final dashboard = File('lib/app/rider_shell/rider_dashboard_view.dart')
        .readAsStringSync();

    test('uses the approved Schedule structure as the only schedule screen',
        () {
      expect(schedule, contains('class RiderScheduleView'));
      expect(schedule, contains('_ScheduleFilter'));
      expect(schedule, contains('_DayGroup'));
      expect(schedule, contains('_ScheduledJobCard'));
      expect(schedule, isNot(contains('EmptySchedule')));
      expect(schedule, isNot(contains('LegacySchedule')));
    });

    test('filters and groups scheduled Rider jobs', () {
      expect(schedule, contains('_ScheduleFilter.all'));
      expect(schedule, contains('_ScheduleFilter.today'));
      expect(schedule, contains('_ScheduleFilter.week'));
      expect(schedule, contains('_ScheduleFilter.vanguard'));
      expect(schedule, contains('assignedRider'));
      expect(schedule, contains("collection('deliveryRequests')"));
      expect(schedule, contains('scheduledAt'));
      expect(schedule, contains('isVisible'));
      expect(schedule, contains('hidden.contains(status)'));
    });

    test('ready-to-start uses backend truth and opens accepted delivery', () {
      expect(schedule, contains("raw['readyToStart'] == true"));
      expect(schedule, contains("raw['canStart'] == true"));
      expect(schedule, contains("status == 'ready_to_start'"));
      expect(schedule, contains('RiderAcceptedJobScreen'));
      expect(schedule, contains('RiderJobOffer.fromFirestore'));
      expect(schedule, isNot(contains('scheduledAt.isBefore(DateTime.now())')));
    });

    test('dashboard and shell route to the canonical schedule screen', () {
      expect(nav, contains('const RiderScheduleView(embedded: true)'));
      expect(nav, contains('onScheduledAccepted: () => select(2)'));
      expect(dashboard, contains('onAction: () => onSelectTab(2)'));
      expect(dashboard, contains('label: \'Schedule\''));
      expect(dashboard, isNot(contains('LegacySchedule')));
    });
  });
}
