import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rider UI overhaul contract', () {
    final home = File('lib/app/home/view/home.dart').readAsStringSync();
    final nav = File('lib/app/bottom_nav/view/app_nav.dart').readAsStringSync();
    final account =
        File('lib/app/account/view/account.dart').readAsStringSync();
    final schedule =
        File('lib/app/schedule/rider_schedule_view.dart').readAsStringSync();
    final notifications =
        File('lib/app/notifications/rider_notifications_view.dart')
            .readAsStringSync();
    final design =
        File('lib/app/rider_design/rider_ui.dart').readAsStringSync();

    test('keeps one canonical navigation shell', () {
      expect(nav, contains('class AppNavView'));
      expect(nav, contains('HomeView()'));
      expect(nav, contains('HistoryView'));
      expect(nav, contains('SupportView'));
      expect(nav, contains('AccountView'));
      expect(nav, isNot(contains('CanonicalRiderApp')));
    });

    test('home implements backend-driven availability states', () {
      expect(home, contains('RideStatus.offline'));
      expect(home, contains('RideStatus.online'));
      expect(home, contains('SetRideStatus'));
      expect(home, contains("collection('riders')"));
      expect(home, contains('TRUST PTS'));
      expect(home, contains('Swipe to go online'));
    });

    test('schedule and notifications reuse existing collections', () {
      expect(schedule, contains("collection('deliveryRequests')"));
      expect(schedule, contains("where('assignedRider'"));
      expect(notifications, contains("collection('notifications')"));
      expect(notifications, contains("where('recipientId'"));
    });

    test('account exposes the canonical Rider destinations', () {
      expect(account, contains('RiderScheduleView'));
      expect(account, contains('RiderNotificationsView'));
      expect(account, contains('EarningsView'));
      expect(account, contains('Trust points'));
      expect(account, contains('Deliveries'));
    });

    test('shared native design is Flutter-only and uses locked colours', () {
      expect(design, contains('0xFF07090F'));
      expect(design, contains('0xFF0D111C'));
      expect(design, contains('0xFF3B82F6'));
      expect(design, contains('class RiderGlassCard'));
      expect(design, isNot(contains('HtmlElementView')));
      expect(design, isNot(contains('WebView')));
    });
  });
}
