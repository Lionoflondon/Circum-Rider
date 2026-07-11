import 'package:circum_rider/app/authentication/view/widgets/circum_auth_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    required bool valid,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CircumAuthEntry(
          controller: TextEditingController(),
          valid: valid,
          loading: false,
          onChanged: (_) {},
          onContinue: () {},
          onGoogle: () {},
          onApple: () {},
          onQr: () {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('locked authentication copy and provider actions render', (
    tester,
  ) async {
    await pump(tester, size: const Size(390, 844), valid: false);
    expect(find.text("What's your phone number\nor email?"), findsOneWidget);
    expect(find.text('Enter phone number or email'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Log in with QR code'), findsOneWidget);
    expect(
      find.textContaining('You consent to receive a verification code'),
      findsOneWidget,
    );
  });

  testWidgets(
    'invalid input disables Continue and valid identifier enables it',
    (tester) async {
      await pump(tester, size: const Size(390, 844), valid: false);
      var button = tester.widget<FilledButton>(
        find.byKey(const Key('circum_auth_continue')),
      );
      expect(button.onPressed, isNull);
      await pump(tester, size: const Size(390, 844), valid: true);
      button = tester.widget<FilledButton>(
        find.byKey(const Key('circum_auth_continue')),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(820, 1180),
    const Size(1440, 1000),
  ]) {
    testWidgets('layout has no overflow at ${size.width}x${size.height}', (
      tester,
    ) async {
      await pump(tester, size: size, valid: true);
      expect(tester.takeException(), isNull);
      expect(find.byType(CircumAuthEntry), findsOneWidget);
    });
  }
}
