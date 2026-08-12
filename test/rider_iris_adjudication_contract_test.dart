import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider difference enters evidence-backed adjudication flow', () {
    final screen = File('lib/app/rider_jobs/rider_job_offer_screen.dart')
        .readAsStringSync();
    final controller = File('lib/app/rider_jobs/rider_delivery_controller.dart')
        .readAsStringSync();

    expect(screen, contains('Request IRIS review'));
    expect(screen, contains('enters Circum adjudication'));
    expect(screen, contains("stage: 'iris_adjudication'"));
    expect(screen, contains('reportDiscrepancy('));
    expect(screen, contains('Collection is paused for adjudication'));
    expect(controller, contains("httpsCallable('reportLoadDiscrepancy')"));
    expect(controller, contains("'evidencePhotos': evidencePhotos"));
    expect(controller, contains("'observedWeightKg': observedWeightKg"));
  });
}
