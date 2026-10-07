import 'package:circum_rider/main.dart';
import 'package:circum_rider/utils/nav/nav_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Back at Rider root bubbles to Android without recursion',
      (tester) async {
    var exits = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') exits++;
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(const CircumRider(
      homeOverride: Scaffold(body: Text('Rider root')),
    ));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(exits, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('Rider root'), findsOneWidget);
  });

  testWidgets('Back pops a Rider detail route without exiting the app',
      (tester) async {
    var exits = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') exits++;
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(const CircumRider(
      homeOverride: Scaffold(body: Text('Rider root')),
    ));
    await tester.pumpAndSettle();
    NavKey.navKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Rider detail')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Rider detail'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Rider detail'), findsNothing);
    expect(find.text('Rider root'), findsOneWidget);
    expect(exits, 0);
    expect(tester.takeException(), isNull);
  });
}
