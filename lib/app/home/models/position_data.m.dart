import 'package:cloud_firestore/cloud_firestore.dart';

class PositionData {
  final String geohash;
  final GeoPoint geopoint;

  PositionData({
    required this.geohash,
    required this.geopoint,
  });

  factory PositionData.fromJson(dynamic json) {
    return PositionData(geohash: json['geohash'], geopoint: json['geopoint']);
  }

  Map<String, dynamic> toJson() {
    return {'geohash': geohash, 'geopoint': geopoint};
  }
}
