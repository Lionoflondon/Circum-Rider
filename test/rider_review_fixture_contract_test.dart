import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('review entry is backend-verified and isolated from production tracking', () {
    final dashboard = File('lib/app/rider_shell/rider_dashboard_view.dart')
        .readAsStringSync();
    final service = File('lib/app/review/rider_review_fixture_service.dart')
        .readAsStringSync();
    final screen = File('lib/app/review/rider_review_fixture_screen.dart')
        .readAsStringSync();

    expect(service, contains("getGooglePlayReviewFixture"));
    expect(dashboard, contains('RiderReviewFixtureService'));
    expect(dashboard, contains('Review location tracking'));
    expect(screen, contains('RiderLocationDisclosureDialog.show(context)'));
    expect(screen, contains('Geolocator.requestPermission()'));
    expect(screen, isNot(contains('updateDeliveryLiveLocation')));
    expect(screen, isNot(contains("deliveryRequests")));
  });
}
