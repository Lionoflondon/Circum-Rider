import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tracking permission is behind the shared disclosure seam', () {
    final controller = File(
      'lib/app/tracking/rider_live_tracking_controller.dart',
    ).readAsStringSync();
    final disclosure = File(
      'lib/app/tracking/rider_location_disclosure.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/app/rider_jobs/rider_job_offer_screen.dart',
    ).readAsStringSync();

    expect(
      controller,
      contains('required RiderLocationDisclosure beforePermission'),
    );
    expect(
      controller.indexOf('_beforePermission?.call()'),
      lessThan(controller.indexOf('Geolocator.requestPermission')),
    );
    expect(controller,
        contains("status: RiderLiveTrackingStatus.permissionRequired"));
    expect(disclosure, contains('Location tracking'));
    expect(disclosure, contains('Continue'));
    expect(disclosure, contains('Not now'));
    expect(screen, contains('RiderLocationDisclosureDialog.show(context)'));
  });
}
