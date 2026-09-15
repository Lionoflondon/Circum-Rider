import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.path;
  String read(String path) => File('$root/$path').readAsStringSync();

  test('native Rider registers a retained, isolate-safe background handler',
      () {
    final source = read('lib/messaging.dart');
    expect(source, contains("@pragma('vm:entry-point')"));
    expect(source, contains('_firebaseMessagingBackgroundHandler'));
    expect(source, contains('Firebase.initializeApp()'));
    final background = source.substring(source.indexOf('@pragma'));
    expect(background, isNot(contains('homeBloc.add(')));
  });

  test('job notification taps route to the backend-authoritative offer feed',
      () {
    final source = read('lib/messaging.dart');
    expect(source, contains('FirebaseMessaging.onMessageOpenedApp'));
    expect(source, contains('getInitialMessage()'));
    expect(source, contains('RiderJobOfferScreen.routeName'));
    expect(source, contains("_riderOfferPushType = 'broadcast-request'"));
  });

  test(
      'Android runtime notification permission and high-priority job channel exist',
      () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    final notifications = read('lib/helper/notifications_helper.dart');
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(notifications, contains("'rider_job_offers'"));
    expect(notifications, contains('Importance.max'));
  });
}
