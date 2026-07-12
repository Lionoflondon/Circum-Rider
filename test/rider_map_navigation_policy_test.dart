import 'package:circum_rider/app/tracking/rider_map_navigation_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  group('RiderMapNavigationPolicy', () {
    test('throttles route refreshes until interval and deviation require it',
        () {
      final now = DateTime.utc(2026, 7, 12, 12);
      final previous = _position(
        lat: 51.5007,
        lng: -0.1246,
        timestamp: now.subtract(const Duration(minutes: 1)),
      );
      final nearby = _position(
        lat: 51.5009,
        lng: -0.1248,
        timestamp: now,
      );
      final deviated = _position(
        lat: 51.5100,
        lng: -0.1400,
        timestamp: now,
      );

      expect(
        RiderMapNavigationPolicy.shouldRefreshRoute(
          current: nearby,
          lastRoutePosition: previous,
          lastRouteRefreshAt: now.subtract(const Duration(seconds: 20)),
          now: now,
        ),
        isFalse,
      );
      expect(
        RiderMapNavigationPolicy.shouldRefreshRoute(
          current: deviated,
          lastRoutePosition: previous,
          lastRouteRefreshAt: now.subtract(const Duration(minutes: 2)),
          now: now,
        ),
        isTrue,
      );
    });

    test('stage change and reconnect force a route refresh', () {
      final now = DateTime.utc(2026, 7, 12, 12);
      final position = _position(lat: 51.5, lng: -0.12, timestamp: now);

      expect(
        RiderMapNavigationPolicy.shouldRefreshRoute(
          current: position,
          lastRoutePosition: position,
          lastRouteRefreshAt: now,
          stageChanged: true,
        ),
        isTrue,
      );
      expect(
        RiderMapNavigationPolicy.shouldRefreshRoute(
          current: position,
          lastRoutePosition: position,
          lastRouteRefreshAt: now,
          reconnected: true,
        ),
        isTrue,
      );
    });

    test('manual pan disables camera following until resumed', () {
      final now = DateTime.utc(2026, 7, 12, 12);
      final previous = _position(lat: 51.5, lng: -0.12, timestamp: now);
      final current = _position(lat: 51.501, lng: -0.121, timestamp: now);

      expect(
        RiderMapNavigationPolicy.shouldMoveCamera(
          current: current,
          previous: previous,
          following: false,
        ),
        isFalse,
      );
      expect(
        RiderMapNavigationPolicy.shouldMoveCamera(
          current: current,
          previous: previous,
          following: true,
        ),
        isTrue,
      );
    });

    test('route bounds include rider pickup and destination', () {
      final bounds = RiderMapNavigationPolicy.boundsFor(const [
        LatLng(51.5, -0.1),
        LatLng(51.6, -0.2),
        LatLng(51.55, -0.15),
      ]);

      expect(bounds.southwest.latitude, 51.5);
      expect(bounds.northeast.latitude, 51.6);
      expect(bounds.southwest.longitude, -0.2);
      expect(bounds.northeast.longitude, -0.1);
    });
  });
}

Position _position({
  required double lat,
  required double lng,
  required DateTime timestamp,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: timestamp,
    accuracy: 12,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}
