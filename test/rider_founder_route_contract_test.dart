import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authenticated Founder access cannot resolve to an empty navigator', () {
    final app = File('lib/app.dart').readAsStringSync();
    final dashboardGate = app.substring(
      app.indexOf('// Authenticated app state'),
      app.indexOf('const MaterialPage(child: AppNavView())'),
    );

    expect(dashboardGate,
        contains('state.currentState == AppState.authenticated'));
    expect(dashboardGate, contains('(internalAccess ||'));
    expect(
      dashboardGate.indexOf('internalAccess ||'),
      lessThan(dashboardGate.indexOf('state.authenticatedStatus')),
    );
  });
}
