import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/app/home/bloc/home_bloc.dart').readAsStringSync();

  test('HomeBloc owns lifecycle-aware presence heartbeat recovery', () {
    expect(source, contains('with WidgetsBindingObserver'));
    expect(source, contains('WidgetsBinding.instance.addObserver(this)'));
    expect(source, contains('WidgetsBinding.instance.removeObserver(this)'));
    expect(source, contains('didChangeAppLifecycleState'));
    expect(source, contains('AppLifecycleState.resumed'));
    expect(source, contains('AppLifecycleState.paused'));
    expect(source, contains('AppLifecycleState.detached'));
    expect(source, contains('AppLifecycleState.hidden'));
    expect(
        source, contains('if (_isLogicallyOnline) _startPresenceHeartbeat();'));
    expect(source, contains('unawaited(_sendPresenceHeartbeat())'));
    final lifecycleStart = source.indexOf('void didChangeAppLifecycleState');
    final lifecycleEnd =
        source.indexOf('void _handleCheckForPushToken', lifecycleStart);
    final lifecycleSource = source.substring(lifecycleStart, lifecycleEnd);
    expect(lifecycleSource, isNot(contains('goOffline')));
  });

  test('accepted delivery states keep presence logically online', () {
    expect(source, contains('RideStatus.acceptedARide'));
    expect(source, contains('RideStatus.userConfirmedRide'));
    expect(source, contains('RideStatus.arrivedAtPickupLocation'));
    expect(source, contains('RideStatus.outForDelivery'));
    expect(source,
        contains('if (auth.currentUser == null || !_isLogicallyOnline)'));
  });
}
