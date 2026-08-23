import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../rider_design/rider_ui.dart';
import '../tracking/rider_location_disclosure.dart';

class RiderReviewFixtureScreen extends StatefulWidget {
  const RiderReviewFixtureScreen({super.key, required this.fixture});

  static const routeName = '/rider/review-fixture';
  final Map<String, dynamic> fixture;

  @override
  State<RiderReviewFixtureScreen> createState() =>
      _RiderReviewFixtureScreenState();
}

class _RiderReviewFixtureScreenState extends State<RiderReviewFixtureScreen> {
  StreamSubscription<Position>? _positionSub;
  Position? _position;
  String? _message;
  bool _started = false;

  @override
  void dispose() {
    unawaited(_positionSub?.cancel());
    super.dispose();
  }

  Future<void> _startReviewTracking() async {
    if (_started) return;
    final disclosed = await RiderLocationDisclosureDialog.show(context);
    if (!mounted || !disclosed) {
      if (mounted) {
        setState(() => _message = 'Location tracking was not started.');
      }
      return;
    }
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        setState(() =>
            _message = 'Location permission was declined. You can try again.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _message =
            'Location permission is blocked. Open settings to continue.');
        return;
      }
      setState(() => _started = true);
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 8,
        ),
      ).listen((position) {
        if (mounted) setState(() => _position = position);
      });
    } catch (_) {
      if (mounted) {
        setState(
            () => _message = 'Location tracking could not start. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.fixture['syntheticRoute'] is Map
        ? Map<String, dynamic>.from(widget.fixture['syntheticRoute'] as Map)
        : const <String, dynamic>{};
    return Scaffold(
      appBar: AppBar(title: const Text('Review location tracking')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.location_on_outlined,
              size: 56, color: RiderPalette.blue),
          const SizedBox(height: 16),
          const Text('Active delivery tracking review',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text('${route['pickupLabel'] ?? 'Review pickup'} → '
              '${route['dropoffLabel'] ?? 'Review drop-off'}'),
          const SizedBox(height: 20),
          Text(_position == null
              ? 'Tracking is ready to demonstrate the location permission flow.'
              : 'Location updates are active for this review route.'),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _started ? null : _startReviewTracking,
            child:
                Text(_started ? 'Tracking active' : 'Start location tracking'),
          ),
        ],
      ),
    );
  }
}
