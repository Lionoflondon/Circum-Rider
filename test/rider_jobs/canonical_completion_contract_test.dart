import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Rider completion uses only the canonical callable and safe payload',
    () {
      final controller = File(
        'lib/app/rider_jobs/rider_delivery_controller.dart',
      ).readAsStringSync();
      final screen = File(
        'lib/app/rider_jobs/rider_job_offer_screen.dart',
      ).readAsStringSync();

      expect(controller, contains("httpsCallable('completeDelivery')"));
      expect(screen, contains('completeDelivery('));
      expect(screen, contains("action == 'verify_receiver_pin'"));
      expect(screen, contains("action == 'complete_delivery'"));
      expect(screen, contains('recordEvidence('));
      expect(screen, contains('if (evidence == null) return;'));
      expect(screen, contains('RiderEvidenceUploadException'));
      expect(screen, isNot(contains("'status':")));
      expect(screen, isNot(contains("'earnings':")));
      expect(screen, isNot(contains("'trust':")));
      expect(screen, isNot(contains("'wallet':")));
      expect(screen, isNot(contains("'businessState':")));
      expect(screen, isNot(contains("'giftState':")));
      expect(screen, isNot(contains("'healthState':")));
      expect(screen, isNot(contains("'notificationState':")));
    },
  );
}
