import 'dart:collection';
import 'dart:io';

import 'package:circum_rider/app/tracking/rider_live_tracking_controller.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_test/flutter_test.dart';

Position _position({
  required double lat,
  required double lng,
  double accuracy = 12,
  DateTime? time,
}) {
  return Position(
    longitude: lng,
    latitude: lat,
    timestamp: time ?? DateTime.utc(2026, 7, 11, 10),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 90,
    headingAccuracy: 5,
    speed: 4,
    speedAccuracy: 1,
  );
}

void main() {
  group('Rider live tracking policy', () {
    test('publishes first location and then throttles duplicate GPS events',
        () {
      final now = DateTime.utc(2026, 7, 11, 10);
      final first = _position(lat: 51.50, lng: -0.10, time: now);
      final duplicate = _position(
        lat: 51.50001,
        lng: -0.10001,
        time: now.add(const Duration(seconds: 3)),
      );

      expect(
        RiderLiveTrackingPolicy.shouldPublish(
          next: first,
          previous: null,
          lastPublishedAt: null,
          now: now,
        ),
        isTrue,
      );
      expect(
        RiderLiveTrackingPolicy.shouldPublish(
          next: duplicate,
          previous: first,
          lastPublishedAt: now,
          now: now.add(const Duration(seconds: 3)),
        ),
        isFalse,
      );
    });

    test('increases responsiveness near pickup or drop-off', () {
      final now = DateTime.utc(2026, 7, 11, 10);
      final previous = _position(lat: 51.5000, lng: -0.1000, time: now);
      final next = _position(
        lat: 51.50009,
        lng: -0.1000,
        time: now.add(const Duration(seconds: 6)),
      );

      expect(
        RiderLiveTrackingPolicy.shouldPublish(
          next: next,
          previous: previous,
          lastPublishedAt: now,
          nearDestination: true,
          now: now.add(const Duration(seconds: 6)),
        ),
        isTrue,
      );
    });

    test('active and terminal delivery states are clearly separated', () {
      expect(RiderLiveTrackingPolicy.isActiveDeliveryStatus('accepted'), true);
      expect(
          RiderLiveTrackingPolicy.isActiveDeliveryStatus('completed'), false);
      expect(
          RiderLiveTrackingPolicy.isTerminalDeliveryStatus('cancelled'), true);
      expect(
          RiderLiveTrackingPolicy.isTerminalDeliveryStatus('delivered'), true);
    });

    test('only the assigned rider can pass client tracking guard', () {
      expect(
        RiderLiveTrackingPolicy.assignedToRider(
          {'assignedRiderId': 'rider-1'},
          'rider-1',
        ),
        true,
      );
      expect(
        RiderLiveTrackingPolicy.assignedToRider(
          {'assignedRiderId': 'rider-2'},
          'rider-1',
        ),
        false,
      );
    });

    test('arrival requires consecutive reliable positions and dwell time', () {
      final hits = Queue<DateTime>();
      final now = DateTime.utc(2026, 7, 11, 10);
      hits.add(now);
      expect(
        RiderLiveTrackingPolicy.shouldSignalArrival(hits: hits, now: now),
        false,
      );
      hits.add(now.add(const Duration(seconds: 9)));
      expect(
        RiderLiveTrackingPolicy.shouldSignalArrival(
          hits: hits,
          now: now.add(const Duration(seconds: 9)),
        ),
        true,
      );
    });

    test('poor accuracy is not treated as reliable arrival evidence', () {
      final position = _position(lat: 51.5, lng: -0.1, accuracy: 120);
      expect(RiderLiveTrackingPolicy.isUsableAccuracy(position), false);
    });

    test('canonical tracking statuses expose one presentation model', () {
      final values = {
        RiderLiveTrackingStatus.live: 'live',
        RiderLiveTrackingStatus.acquiring: 'acquiringLocation',
        RiderLiveTrackingStatus.poorAccuracy: 'poorGpsAccuracy',
        RiderLiveTrackingStatus.foregroundOnly: 'foregroundOnly',
        RiderLiveTrackingStatus.backgroundActive: 'backgroundTrackingActive',
        RiderLiveTrackingStatus.offline: 'offline',
        RiderLiveTrackingStatus.reconnecting: 'reconnecting',
        RiderLiveTrackingStatus.permissionRequired: 'permissionRequired',
        RiderLiveTrackingStatus.servicesDisabled: 'locationServicesDisabled',
        RiderLiveTrackingStatus.arrivedAtPickup: 'arrivedAtPickup',
        RiderLiveTrackingStatus.arrivedAtDropoff: 'arrivedAtDropoff',
        RiderLiveTrackingStatus.stopped: 'trackingStopped',
      };

      for (final entry in values.entries) {
        expect(entry.key.internalValue, entry.value);
        expect(entry.key.title, isNotEmpty);
        expect(entry.key.supportingText, isNotEmpty);
        expect(entry.key.accessibilityLabel, contains(entry.key.title));
      }
    });

    test('stale and impossible GPS readings are rejected cautiously', () {
      final now = DateTime.utc(2026, 7, 11, 10);
      final stale = _position(
        lat: 51.5,
        lng: -0.1,
        time: now.subtract(const Duration(minutes: 4)),
      );
      final previous = _position(lat: 51.5, lng: -0.1, time: now);
      final impossible = _position(
        lat: 52.5,
        lng: -1.1,
        accuracy: 30,
        time: now.add(const Duration(seconds: 10)),
      );

      expect(RiderLiveTrackingPolicy.isStalePosition(stale, now: now), true);
      expect(
        RiderLiveTrackingPolicy.isImpossibleJump(
          previous: previous,
          next: impossible,
        ),
        true,
      );
    });
  });

  group('Rider live tracking integration contract', () {
    final source = File('lib/app/tracking/rider_live_tracking_controller.dart')
        .readAsStringSync();
    final accepted = File('lib/app/rider_jobs/rider_job_offer_screen.dart')
        .readAsStringSync();
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    test('uses the existing Sender live-tracking document contract', () {
      expect(source, contains(".collection('deliveryRequests')"));
      expect(source, contains(".collection('tracking')"));
      expect(source, contains(".doc('liveLocation')"));
      expect(source, contains("'riderLiveLocation'"));
    });

    test('accepted delivery screen starts tracking from backend state', () {
      expect(accepted, contains('RiderLiveTrackingController'));
      expect(accepted, contains('_syncLiveTracking'));
      expect(accepted, contains('RiderLiveTrackingPolicy.assignedToRider'));
      expect(accepted, contains('arrived_at_pickup'));
      expect(accepted, contains('arrived_at_dropoff'));
    });

    test('tracking UI renders mandatory states and recovery actions', () {
      expect(source, contains('Live tracking'));
      expect(source, contains('Foreground tracking only'));
      expect(source, contains('Offline - waiting for connection'));
      expect(source, contains('Location permission required'));
      expect(accepted, contains('_TrackingEtaCard'));
      expect(accepted, contains('_TrackingPermissionCard'));
      expect(accepted, contains('Geolocator.openAppSettings'));
      expect(accepted, contains('Geolocator.openLocationSettings'));
    });

    test('accepted delivery keeps tracking overlays in the Rider glass system',
        () {
      expect(accepted, contains('RiderGlassSurface'));
      expect(accepted, contains("CircleId('rider-live-pulse')"));
      expect(accepted, contains('accessibilityLabel'));
      expect(accepted, contains('RiderTypography.mono'));
    });

    test('Android has one background location permission declaration', () {
      expect(
        RegExp('ACCESS_BACKGROUND_LOCATION').allMatches(manifest).length,
        1,
      );
      expect(manifest, contains('ACCESS_FINE_LOCATION'));
      expect(manifest, contains('FOREGROUND_SERVICE'));
    });
  });
}
