import 'package:dio/dio.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

extension on DirectionsService {
  // Decode Google's encoded polyline
  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int result = 1;
      int shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63 - 1;
        result += b << shift;
        shift += 5;
      } while (b >= 0x1f);
      lat += (result >> 1) * (result & 1 != 0 ? -1 : 1);

      result = 1;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63 - 1;
        result += b << shift;
        shift += 5;
      } while (b >= 0x1f);
      lng += (result >> 1) * (result & 1 != 0 ? -1 : 1);

      points.add(LatLng(lat / 100000.0, lng / 100000.0));
    }

    return points;
  }
}

class DirectionsService {
  final Dio _dio;
  final FlutterTts flutterTts = FlutterTts();

  DirectionsService() : _dio = Dio();

  Future<List<DirectionStep>> getDetailedDirections(
      LatLng origin, LatLng destination) async {
    final String url = 'https://maps.googleapis.com/maps/api/directions/json';

    try {
      final response = await _dio.get(
        url,
        queryParameters: {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'key': 'AIzaSyDWH0L6pjdf2W_ZZrjfv6z5OvMZQ2TVNMI',
          'polyline': 'true'
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> routes = response.data['routes'];

        if (routes.isNotEmpty) {
          final List<dynamic> legs = routes[0]['legs'];
          if (legs.isNotEmpty) {
            final List<dynamic> steps = legs[0]['steps'];
            return steps.map((step) {
              // Decode the polyline for each step
              List<LatLng> decodedPolyline =
                  decodePolyline(step['polyline']['points']);
              return DirectionStep(
                startLocation: LatLng(
                  step['start_location']['lat'],
                  step['start_location']['lng'],
                ),
                endLocation: LatLng(
                  step['end_location']['lat'],
                  step['end_location']['lng'],
                ),
                instruction: step['html_instructions'],
                maneuver: step['maneuver'] ?? '',
                polylinePoints: decodedPolyline, // Add decoded polyline points
              );
            }).toList();
          }
        }
      }
    } catch (e) {
      print('Error fetching directions: $e');
    }

    return [];
  }

  Future<void> speakDirection(String direction) async {
    await flutterTts.speak(direction);
  }
}

class DirectionStep {
  final LatLng startLocation;
  final LatLng endLocation;
  final String instruction;
  final String maneuver;
  final List<LatLng> polylinePoints; // New property

  DirectionStep({
    required this.startLocation,
    required this.endLocation,
    required this.instruction,
    required this.maneuver,
    this.polylinePoints = const [], // Default to empty list
  });

  factory DirectionStep.fromJson(Map<String, dynamic> json) {
    // This method will now be handled in the service
    throw UnimplementedError('Use DirectionsService to create steps');
  }
}
