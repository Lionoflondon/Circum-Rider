import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import 'bloc/home_bloc.dart';
import '../tracking/rider_location_disclosure.dart';

Future<LocationPermission?> resolveRiderOnlinePermission({
  required Future<LocationPermission> Function() checkPermission,
  required Future<LocationPermission> Function() requestPermission,
  required Future<bool> Function() disclose,
}) async {
  final permission =
      await checkPermission().timeout(const Duration(seconds: 20));
  if (permission != LocationPermission.denied) return permission;
  if (!await disclose()) return null;
  return requestPermission().timeout(const Duration(seconds: 20));
}

/// Permission prompts belong to explicit taps, never heartbeat/reconnect work.
Future<void> toggleRiderAvailability(BuildContext context,
    {required bool online}) async {
  final bloc = context.read<HomeBloc>();
  if (online) {
    bloc.add(SetRideStatus(status: RideStatus.offline));
    return;
  }
  try {
    final permission = await resolveRiderOnlinePermission(
      checkPermission: Geolocator.checkPermission,
      requestPermission: Geolocator.requestPermission,
      disclose: () => RiderLocationDisclosureDialog.show(context),
    );
    if (!context.mounted || bloc.isClosed || permission == null) return;
    // HomeBloc provides the permission/settings error and validates fresh GPS.
    bloc.add(SetRideStatus(status: RideStatus.online));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Location access could not be checked. Try again.'),
    ));
  }
}
