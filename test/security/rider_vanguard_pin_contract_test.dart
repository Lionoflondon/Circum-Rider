import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current;

  String read(String relativePath) =>
      File('${root.path}/$relativePath').readAsStringSync();

  test('Rider does not read expected Vanguard PIN secrets from delivery data',
      () {
    final files = <String>[
      'lib/app/rider_jobs/rider_delivery_controller.dart',
      'lib/app/rider_jobs/rider_job_offer_screen.dart',
      'lib/app/tracking/rider_live_tracking_controller.dart',
    ];

    for (final file in files) {
      final source = read(file);
      expect(source, isNot(contains("['collectionPin']")), reason: file);
      expect(source, isNot(contains("['deliveryPin']")), reason: file);
      expect(source, isNot(contains("['pickupPin']")), reason: file);
      expect(source, isNot(contains("['dropoffPin']")), reason: file);
      expect(source, isNot(contains("['vanguardReviewRequired']")),
          reason: file);
      expect(source, isNot(contains('.collectionPin')), reason: file);
      expect(source, isNot(contains('.deliveryPin')), reason: file);
    }
  });
}
