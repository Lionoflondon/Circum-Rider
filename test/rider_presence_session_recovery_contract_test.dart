import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backend-online Rider resumes the presence heartbeat after reload', () {
    final dashboard = File('lib/app/rider_shell/rider_dashboard_view.dart')
        .readAsStringSync();
    final home = File('lib/app/home/bloc/home_bloc.dart').readAsStringSync();

    expect(dashboard, contains('_presenceRecoveryRequested'));
    expect(dashboard, contains('ResumePresenceHeartbeat()'));
    expect(home, contains('on<ResumePresenceHeartbeat>'));
    expect(home, contains('_handleResumePresenceHeartbeat'));
    expect(home, contains('_startPresenceHeartbeat()'));
    expect(home, contains("httpsCallable('updateRiderPresence')"));
  });

  test('Firebase session is cleared only by the explicit SignOut event', () {
    final auth =
        File('lib/app/authentication/bloc/auth_bloc.dart').readAsStringSync();
    final signOutCalls = RegExp(r'await auth\.signOut\(\);').allMatches(auth);

    expect(signOutCalls.length, 1);
    expect(auth, contains('on<SignOut>('));
  });
}
