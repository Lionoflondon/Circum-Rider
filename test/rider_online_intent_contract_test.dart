import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final bloc = File('lib/app/home/bloc/home_bloc.dart').readAsStringSync();
  final state = File('lib/app/home/bloc/home_state.dart').readAsStringSync();
  final dashboard =
      File('lib/app/rider_shell/rider_dashboard_view.dart').readAsStringSync();

  test('Go online records intent without client-side approval or GPS gating',
      () {
    expect(bloc,
        isNot(contains('RiderAccountStateResolver.canOperate(accountState)')));
    expect(
        bloc, isNot(contains('Complete your verification to start earning.')));
    expect(bloc,
        contains("if (locationPayload != null) 'location': locationPayload"));
    expect(bloc, contains(".httpsCallable('goOnline')"));
    expect(dashboard, contains('final allowed = !starting;'));
  });

  test('Rider UI keeps online intent separate from backend dispatch authority',
      () {
    expect(state, contains('bool riderIntentOnline;'));
    expect(state, contains('bool dispatchEligible;'));
    expect(state, contains('String? dispatchReason;'));
    expect(bloc, contains("responseData['dispatchEligible'] == true"));
    expect(bloc, contains("responseData['reason']?.toString()"));
    expect(bloc, contains("value['onlineIntent'] != false"));
    for (final copy in <String>[
      'Online — getting your location',
      'Online — approval required before jobs',
      'Online — vehicle review required',
      'Online — ready for jobs',
    ]) {
      expect(dashboard, contains(copy));
    }
  });

  test('heartbeat receives backend dispatch projection and never self-promotes',
      () {
    expect(bloc, contains(".httpsCallable('updateRiderPresence')"));
    expect(bloc, contains("result['dispatchEligible'] == true"));
    expect(bloc, contains("result['reason']?.toString()"));
    expect(bloc, isNot(contains('dispatchEligible: true,')));
  });
}
