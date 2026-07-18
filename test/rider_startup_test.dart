import 'dart:async';

import 'package:circum_rider/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  testWidgets('Rider startup renders loading before initialization completes',
      (tester) async {
    final completer = Completer<void>();

    await tester.pumpWidget(RiderStartupApp(
      initializer: () => completer.future,
      appBuilder: (_) => const MaterialApp(home: Text('Rider ready')),
    ));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF131313));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    completer.complete();
    await tester.pumpAndSettle();
    expect(find.text('Rider ready'), findsOneWidget);
  });

  testWidgets('Rider startup shows a retryable dark error state',
      (tester) async {
    var attempts = 0;

    await tester.pumpWidget(RiderStartupApp(
      timeout: const Duration(milliseconds: 10),
      initializer: () async {
        attempts += 1;
        if (attempts == 1) throw StateError('startup failed');
      },
      appBuilder: (_) => const MaterialApp(home: Text('Rider ready')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong.'), findsOneWidget);
    expect(find.text('Reference: RDR-START-001'), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF07090F));

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Rider ready'), findsOneWidget);
    expect(attempts, 2);
  });

  test('Rider bootstrap avoids destructive cache races', () {
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    final index = File('web/index.html').readAsStringSync();

    expect(bootstrap, contains("rider-web-cache-v2"));
    expect(bootstrap, isNot(contains('caches.delete')));
    expect(bootstrap, isNot(contains('registration.unregister')));
    expect(bootstrap, contains('showRiderBootstrapError'));
    expect(index, contains('id="startup-shell"'));
    expect(index, contains('flutter-first-frame'));
    expect(index, contains('RDR-WEB-BOOT-001'));
  });
}
