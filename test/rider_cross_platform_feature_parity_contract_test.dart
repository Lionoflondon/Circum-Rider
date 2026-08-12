import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rider app and web feature parity with platform isolation', () {
    final mobile = File('lib/main.dart').readAsStringSync();
    final web = File('lib/main_rider_web.dart').readAsStringSync();
    final delivery = File('lib/app/rider_jobs/rider_job_offer_screen.dart')
        .readAsStringSync();
    final controller = File('lib/app/rider_jobs/rider_delivery_controller.dart')
        .readAsStringSync();

    test('both shells mount the same Rider product surface', () {
      expect(mobile, contains('CircumRider('));
      expect(web, contains('CircumRider('));
      expect(delivery, contains('RiderAcceptedJobScreen'));
      expect(delivery, contains('_activeAssignedDelivery'));
      expect(delivery, contains('_reportIrisDifference'));
      expect(delivery, contains('verify_collection_pin'));
      expect(delivery, contains('verify_receiver_pin'));
      expect(controller, contains("httpsCallable('reportLoadDiscrepancy')"));
      expect(controller,
          contains("httpsCallable('updateDeliveryTrackingStatus')"));
    });

    test('web and native bootstrap concerns never mix', () {
      expect(mobile, isNot(contains("dart:html")));
      expect(mobile, isNot(contains('RiderWebBootstrapGate')));
      expect(
          mobile, isNot(contains('RIDER_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY')));
      expect(web, contains("dart:html"));
      expect(web, contains('RiderWebBootstrapGate'));
      expect(web, isNot(contains('FlutterLocalNotificationsPlugin')));
      expect(web, isNot(contains('FirebaseMessaging.onBackgroundMessage')));
    });

    test('platform-specific capability differences stay explicit', () {
      expect(delivery, contains('if (kIsWeb || pickup == null'));
      expect(delivery, contains('return const _MapFallback()'));
      final tracking =
          File('lib/app/tracking/rider_live_tracking_controller.dart')
              .readAsStringSync();
      expect(tracking, contains('backgroundCapable: !kIsWeb'));
      expect(tracking, contains('if (kIsWeb || permission =='));
    });
  });
}
