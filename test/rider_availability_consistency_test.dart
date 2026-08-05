import 'dart:io';

import 'package:circum_rider/app/home/bloc/home_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final dashboard = File('lib/app/rider_shell/rider_dashboard_view.dart');
  final state = File('lib/app/home/bloc/home_state.dart');
  final nav = File('lib/app/bottom_nav/view/app_nav.dart');
  final jobs = File('lib/app/rider_jobs/rider_job_offer_screen.dart');
  final homeBloc = File('lib/app/home/bloc/home_bloc.dart');

  test('dashboard renders availability from HomeState only', () {
    final source = dashboard.readAsStringSync();
    expect(source, contains('home.availability.isOnline'));
    expect(source, isNot(contains('online: data.isOnline')));
    expect(source, isNot(contains('final mergedHome = homeState.copyWith')));
  });

  test('availability model requires fresh location before online', () {
    final source = state.readAsStringSync();
    expect(source, contains('RiderAvailabilityStatus.waitingForLocation'));
    expect(source, contains("presence['dispatchEligible'] == true"));
    expect(source, contains('locationFresh && heartbeatFresh'));
    expect(source, contains('const Duration(minutes: 2)'));
  });

  test('production dashboard does not render internal diagnostics', () {
    final source = dashboard.readAsStringSync();
    expect('_InternalDiagnosticsCard('.allMatches(source), hasLength(1));
    expect(source, isNot(contains('rank.overrideReason')));
  });

  test('navigation and jobs use canonical availability only', () {
    final navSource = nav.readAsStringSync();
    final jobsSource = jobs.readAsStringSync();
    expect(navSource, contains('home.availability.isOnline'));
    expect(navSource, isNot(contains('home.rideStatus == RideStatus.online')));
    expect(jobsSource, contains('home.availability.dispatchEligible'));
    expect(
      jobsSource,
      isNot(contains("riderData['availabilityStatus'] ?? riderData['status']")),
    );
  });

  test('missing assignment fields remain visible as unassigned offers', () {
    final dashboardSource = dashboard.readAsStringSync();
    final jobsSource = jobs.readAsStringSync();
    const nullSafeAssignment = "value == null ? '' : '\u0024value'.trim()";
    expect(dashboardSource, contains(nullSafeAssignment));
    expect(jobsSource, contains(nullSafeAssignment));
  });

  test('fresh presence is online and dispatch eligible', () {
    final now = DateTime.utc(2026, 8, 4, 12);
    final availability = RiderAvailability.fromPresence({
      'isOnline': true,
      'availabilityStatus': 'available',
      'dispatchEligible': true,
      'lastHeartbeatAt': now.millisecondsSinceEpoch,
      'lastLocationAt': now.millisecondsSinceEpoch,
      'currentLocation': {'updatedAt': now.millisecondsSinceEpoch},
    }, now: now);
    expect(availability.status, RiderAvailabilityStatus.online);
    expect(availability.dispatchEligible, isTrue);
    expect(availability.intendsToBeOnline, isTrue);
  });

  test('stale location cannot render as online', () {
    final now = DateTime.utc(2026, 8, 4, 12);
    final stale = now.subtract(const Duration(minutes: 3));
    final availability = RiderAvailability.fromPresence({
      'isOnline': true,
      'availabilityStatus': 'available',
      'dispatchEligible': true,
      'lastHeartbeatAt': now.millisecondsSinceEpoch,
      'lastLocationAt': stale.millisecondsSinceEpoch,
      'currentLocation': {'updatedAt': stale.millisecondsSinceEpoch},
    }, now: now);
    expect(
      availability.status,
      RiderAvailabilityStatus.waitingForLocation,
    );
    expect(availability.isOnline, isFalse);
    expect(availability.dispatchEligible, isFalse);
    expect(availability.intendsToBeOnline, isTrue);
  });

  test('offline wins over a stale online status field', () {
    final now = DateTime.utc(2026, 8, 4, 12);
    final availability = RiderAvailability.fromPresence({
      'isOnline': false,
      'status': 'online',
      'availabilityStatus': 'offline',
      'dispatchEligible': false,
      'lastHeartbeatAt': now.millisecondsSinceEpoch,
      'currentLocation': {'updatedAt': now.millisecondsSinceEpoch},
    }, now: now);
    expect(availability.status, RiderAvailabilityStatus.offline);
    expect(availability.intendsToBeOnline, isFalse);
  });

  test('Founder online transition runs backend operational preflight', () {
    final source = homeBloc.readAsStringSync();
    expect(source, contains("static const _founderUid = 'T2eV6PQucdUKmwSipEn2NAn4N9z1'"));
    expect(source, contains("httpsCallable('founderRiderOperationalPreflight')"));
    expect(source, contains('FOUNDER_PREFLIGHT_FAILED'));
  });

  test('online failures retain structured callable diagnostics', () {
    final source = homeBloc.readAsStringSync();
    expect(source, contains('[RIDER_GO_ONLINE_FAILURE]'));
    expect(source, contains('error.code'));
    expect(source, contains('error.details'));
    expect(source, contains('FUNCTION_'));
    expect(source, contains('UNKNOWN_INTERNAL_ERROR'));
    expect(source, isNot(contains("fallback: 'Could not go online. Try again.'")));
  });
}
