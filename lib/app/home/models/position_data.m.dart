import 'package:cloud_firestore/cloud_firestore.dart';

class PositionData {
  final String geohash;
  final GeoPoint geopoint;

  PositionData({
    required this.geohash,
    required this.geopoint,
  });

  factory PositionData.fromJson(dynamic json) {
    final GeoPoint geoPoint = json['geopoint'].runtimeType == GeoPoint
        ? json['geopoint']
        : GeoPoint(
            json['geopoint']['_latitude'], json['geopoint']['_longitude']);
    return PositionData(geohash: json['geohash'], geopoint: geoPoint);
  }

  Map<String, dynamic> toJson() {
    return {'geohash': geohash, 'geopoint': geopoint};
  }
}
