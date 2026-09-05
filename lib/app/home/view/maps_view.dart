import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../authentication/bloc/auth_bloc.dart';
import '../bloc/home_bloc.dart';

class MapsView extends StatefulWidget {
  const MapsView({Key? key}) : super(key: key);

  @override
  State<MapsView> createState() => _MapsViewState();
}

class _MapsViewState extends State<MapsView> {
  static const _mapControllerTimeout = Duration(seconds: 15);
  GlobalKey mapKey = GlobalKey();

  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  final CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(51.498186, -0.114651),
    zoom: 8,
  );

  Future<void> setMapFitToTour(Set<Polyline> p) async {
    final points = p.expand((polyline) => polyline.points).toList();
    if (points.isEmpty) return;
    double minLat = points.first.latitude;
    double minLong = points.first.longitude;
    double maxLat = points.first.latitude;
    double maxLong = points.first.longitude;
    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLong) minLong = point.longitude;
      if (point.longitude > maxLong) maxLong = point.longitude;
    }

    try {
      final GoogleMapController mapController =
          await _controller.future.timeout(_mapControllerTimeout);
      await mapController
          .animateCamera(CameraUpdate.newLatLngBounds(
              LatLngBounds(
                  southwest: LatLng(minLat, minLong),
                  northeast: LatLng(maxLat, maxLong)),
              70))
          .timeout(_mapControllerTimeout);
    } on TimeoutException {
      return;
    } catch (_) {
      // A disposed or unavailable native map must not escape into the UI.
      return;
    }
  }

  Future<void> changeCameraPosition(CameraPosition cameraPosition) async {
    try {
      final GoogleMapController mapController =
          await _controller.future.timeout(_mapControllerTimeout);
      await mapController
          .animateCamera(
            CameraUpdate.newCameraPosition(cameraPosition),
          )
          .timeout(_mapControllerTimeout);
    } on TimeoutException {
      return;
    } catch (_) {
      // A disposed or unavailable native map must not escape into the UI.
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(builder: (context, state) {
      if (state.mapCameraStatus == MapCameraStatus.initialized &&
          context.read<AuthBloc>().state.locationData != null &&
          _controller.isCompleted == true) {
        changeCameraPosition(CameraPosition(
          target: LatLng(context.read<AuthBloc>().state.locationData!.latitude,
              context.read<AuthBloc>().state.locationData!.longitude),
          zoom: 15,
        ));

        context.read<HomeBloc>().add(
            SetMapCameraStatus(status: MapCameraStatus.showingDeviceLocation));
      }
      if (state.sourceAndDestinationStatus ==
              SourceAndDestinationStatus.selected &&
          state.mapCameraStatus !=
              MapCameraStatus.showingSourceAndDestinationLocations) {
        setMapFitToTour(Set<Polyline>.of(state.polylines));
        context.read<HomeBloc>().add(SetMapCameraStatus(
            status: MapCameraStatus.showingSourceAndDestinationLocations));
      }
      if (state.activeRequest != null &&
          (state.rideStatus == RideStatus.userConfirmedRide ||
              state.rideStatus == RideStatus.outForDelivery ||
              state.rideStatus == RideStatus.arrivedAtPickupLocation) &&
          state.broadcastStatus == BroadcastStatus.initialized) {
        context.read<HomeBloc>().add(BroadcastLocation());
      }

      if (kIsWeb) {
        return const _WebMapUnavailable();
      }

      return GoogleMap(
        // key: mapKey,
        mapType: MapType.normal,
        // myLocationEnabled: true,
        initialCameraPosition: _initialCameraPosition,
        cameraTargetBounds: CameraTargetBounds.unbounded,
        onMapCreated: (GoogleMapController controller) async {
          if (!_controller.isCompleted) _controller.complete(controller);
        },
        markers: Set<Marker>.of(state.markers.values),
        polylines: Set<Polyline>.of(state.polylines),
      );
    });
  }
}

class _WebMapUnavailable extends StatelessWidget {
  const _WebMapUnavailable();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF131313),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, color: Color(0xFF6EA8FF), size: 36),
          SizedBox(height: 12),
          Text(
            'Map unavailable in the Rider web app',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Use the Rider mobile app for live navigation.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFB6BECF), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
