import 'package:cloud_firestore/cloud_firestore.dart';

class PositionData {
  final String geohash;
  final GeoPoint geopoint;

  PositionData({
    required this.geohash,
    required this.geopoint,
  });

  factory PositionData.fromJson(dynamic json) {
    final source = json is Map ? json : const <String, dynamic>{};
    final point = source['geopoint'] ?? source;
    final GeoPoint geoPoint;
    if (point is GeoPoint) {
      geoPoint = point;
    } else if (point is Map) {
      final latitude = NumberParsing.coordinate(
        point['latitude'] ?? point['lat'] ?? point['_latitude'],
      );
      final longitude = NumberParsing.coordinate(
        point['longitude'] ??
            point['lng'] ??
            point['lon'] ??
            point['_longitude'],
      );
      geoPoint = GeoPoint(latitude, longitude);
    } else {
      geoPoint = const GeoPoint(0, 0);
    }
    return PositionData(
        geohash: '${source['geohash'] ?? ''}', geopoint: geoPoint);
  }

  Map<String, dynamic> toJson() {
    return {'geohash': geohash, 'geopoint': geopoint};
  }
}

class NumberParsing {
  static double coordinate(dynamic value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    return parsed?.isFinite == true ? parsed! : 0;
  }
}
