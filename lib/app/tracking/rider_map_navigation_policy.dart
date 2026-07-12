import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RiderMapNavigationPolicy {
  static const routeRefreshMinInterval = Duration(seconds: 45);
  static const routeDeviationMeters = 90.0;
  static const cameraMoveMeters = 18.0;

  static bool shouldRefreshRoute({
    required Position current,
    Position? lastRoutePosition,
    DateTime? lastRouteRefreshAt,
    DateTime? now,
    bool stageChanged = false,
    bool reconnected = false,
  }) {
    if (stageChanged || reconnected) return true;
    if (lastRoutePosition == null || lastRouteRefreshAt == null) return true;
    final currentTime = now ?? DateTime.now();
    if (currentTime.difference(lastRouteRefreshAt) < routeRefreshMinInterval) {
      return false;
    }
    return distanceBetween(current, lastRoutePosition) >= routeDeviationMeters;
  }

  static bool shouldMoveCamera({
    required Position current,
    Position? previous,
    required bool following,
  }) {
    if (!following) return false;
    if (previous == null) return true;
    return distanceBetween(current, previous) >= cameraMoveMeters;
  }

  static double distanceBetween(Position a, Position b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  static LatLngBounds boundsFor(Iterable<LatLng> points) {
    final list = points.toList(growable: false);
    if (list.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(0, 0),
        northeast: const LatLng(0, 0),
      );
    }
    final minLat = list.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat = list.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final minLng = list.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final maxLng = list.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
