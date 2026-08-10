import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider offer screen consumes the secure backend projection', () {
    final source = File(
      'lib/app/rider_jobs/rider_job_offer_screen.dart',
    ).readAsStringSync();

    expect(source, contains("httpsCallable('getAvailableRequests')"));
    expect(source, contains("payload['nearestRequests']"));
    expect(
      source,
      isNot(
        contains(
          ".collection('deliveryRequests')\n"
          "                        .where('status', isEqualTo: 'requested')",
        ),
      ),
    );
  });
}
