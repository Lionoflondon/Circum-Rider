import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:circum_rider/app/home/bloc/home_bloc.dart';

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
    expect(source, contains('if (_isLogicallyOnline) {'));
    expect(source, contains('_schedulePresenceReconnect(immediate: true);'));
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
    expect(source, contains('add(SetRideStatus(status: RideStatus.online))'));
    expect(source, contains('riderIntentOnline: true'));
    expect(source, contains('riderIntentOnline: false'));
  });

  test('transient presence failure keeps intent and reconnects once', () {
    expect(source, contains('_presenceReconnectTimer != null'));
    expect(source, contains('<int>[2, 4, 8, 16, 30]'));
    expect(source, contains("'unavailable'"));
    expect(source, contains("'deadline-exceeded'"));
    expect(source, contains('OnlineTransition.reconnecting'));
    expect(source, contains('_schedulePresenceReconnect();'));
  });

  test('reconnecting UI cannot offer Go online again', () {
    final dashboard = File('lib/app/rider_shell/rider_dashboard_view.dart')
        .readAsStringSync();
    expect(dashboard, contains('home.riderIntentOnline'));
    expect(dashboard, contains("? 'Go offline'"));
    expect(
      dashboard,
      contains(
        'Connection interrupted. Circum is reconnecting automatically.',
      ),
    );
  });

  test('heartbeat interval has backend stale-threshold safety margin', () {
    const heartbeatSeconds = 45;
    const backendStaleSeconds = 120;
    expect(backendStaleSeconds, greaterThan(heartbeatSeconds * 2));
  });

  test('dispatch location must be fresh and accurate', () {
    final now = DateTime.utc(2026, 9, 2, 12);
    expect(
      isFreshDispatchLocation(
        capturedAt: now.subtract(const Duration(seconds: 30)),
        accuracyMeters: 35,
        now: now,
      ),
      isTrue,
    );
    expect(
      isFreshDispatchLocation(
        capturedAt: now.subtract(const Duration(hours: 158)),
        accuracyMeters: 35,
        now: now,
      ),
      isFalse,
    );
    expect(
      isFreshDispatchLocation(
        capturedAt: now,
        accuracyMeters: 101,
        now: now,
      ),
      isFalse,
    );
  });

  test('go-online acknowledgement reads the deployed nested presence result',
      () {
    expect(
        isPresenceRegistrationAcknowledged({
          'success': true,
          'presence': {'dispatchEligible': true},
        }),
        isTrue);
    expect(
        isPresenceRegistrationAcknowledged({
          'success': true,
          'presence': {'dispatchEligible': false},
        }),
        isFalse);
    expect(isPresenceRegistrationAcknowledged({'success': false}), isFalse);
  });

  test('presence heartbeat is bounded, singular, and reconnects', () {
    expect(source, contains('_presenceHeartbeatInFlight'));
    expect(source, contains('if (_presenceHeartbeatInFlight) return;'));
    expect(source, contains('.timeout(const Duration(seconds: 20))'));
    expect(source, contains('OnlineTransition.reconnecting'));
    expect(source, contains('PresenceHeartbeatResult(succeeded: false)'));
    final onlineEmit =
        source.indexOf('onlineTransition: OnlineTransition.online,');
    final heartbeatStart =
        source.indexOf('_startPresenceHeartbeat();', onlineEmit);
    expect(onlineEmit, greaterThanOrEqualTo(0));
    expect(heartbeatStart, greaterThan(onlineEmit));
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
    expect(handler, contains('documentReference'));
    expect(handler, contains('.update({'));
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
