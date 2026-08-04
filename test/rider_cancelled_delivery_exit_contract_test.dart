import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source =
      File('lib/app/rider_jobs/rider_job_offer_screen.dart').readAsStringSync();

  test('accepted job exits once when backend reports a terminal state', () {
    expect(
      source,
      contains('RiderLiveTrackingPolicy.isTerminalDeliveryStatus(terminal)'),
    );
    expect(source, contains('if (_terminalExitScheduled) return;'));
    expect(source, contains('publishStop: false'));
    expect(source, contains('Navigator.of(context).pop()'));
  });
}
