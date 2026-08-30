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

  test('explicit online intent persists and restores after recreation', () {
    expect(source,
        contains("const _desiredOnlineStateKey = 'desiredOnlineState';"));
    expect(source, contains('setBool(_desiredOnlineStateKey, true)'));
    expect(source, contains('setBool(_desiredOnlineStateKey, false)'));
    expect(source, contains("prefs.getBool(_desiredOnlineStateKey) == true"));
    expect(
        source,
        contains(
            'if (desiredOnline || presenceOnline || statusString == \'online\')'));
    expect(source, contains('if (desiredOnline && !presenceOnline)'));
  });

  test('offline intent is not changed by lifecycle transitions', () {
    final lifecycleStart = source.indexOf('void didChangeAppLifecycleState');
    final lifecycleEnd =
        source.indexOf('void _handleCheckForPushToken', lifecycleStart);
    final lifecycleSource = source.substring(lifecycleStart, lifecycleEnd);
    expect(lifecycleSource, isNot(contains('_desiredOnlineStateKey')));
    expect(lifecycleSource, isNot(contains('setBool')));
  });

  test('legacy ride-assignment polling cannot strand or double-complete', () {
    final handler = source.substring(
      source.indexOf('final Completer<bool> rideAssigned = Completer();'),
      source.indexOf('// The ride was not assigned to this rider in 30s'),
    );

    expect(handler, contains('Timer? assignmentTimer'));
    expect(handler, contains('if (!rideAssigned.isCompleted)'));
    expect(handler, contains('docReference.get().timeout'));
    expect(handler, contains('documentReference.update'));
    expect(handler, contains('.timeout(const Duration(seconds: 10))'));
    expect(handler, contains('rideAssigned.future.timeout'));
    expect(handler, contains('assignmentTimer?.cancel()'));
    expect(handler, contains('if (!rideAssigned.isCompleted)'));
    expect(
        handler,
        contains(
            'if (!rideAssigned.isCompleted) rideAssigned.complete(true);'));
    expect(
        handler,
        contains(
            'if (!rideAssigned.isCompleted) rideAssigned.complete(false);'));
  });
}
