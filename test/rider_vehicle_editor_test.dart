import 'package:circum_rider/app/rider_shell/rider_profile_details_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty vehicle keeps the modal open with visible validation',
      (tester) async {
    Map<String, dynamic>? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          result = await showModalBottomSheet<Map<String, dynamic>>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const RiderVehicleEditor(),
          );
        },
        child: const Text('Open editor'),
      ),
    ))));
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    final manufacturer = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(manufacturer.controller!.text, isEmpty);
    await tester.ensureVisible(find.text('Save vehicle'));
    await tester.tap(find.text('Save vehicle'));
    await tester.pumpAndSettle();
    expect(find.text('Vehicle type and registration are required.'),
        findsOneWidget);
    expect(find.byType(RiderVehicleEditor), findsOneWidget);
    expect(result, isNull);
    await tester.enterText(find.byType(TextField).first, 'Bicycle');
    await tester.enterText(find.byType(TextField).at(5), 'QA-ONLY');
    await tester.ensureVisible(find.text('Save vehicle'));
    await tester.tap(find.text('Save vehicle'));
    await tester.pumpAndSettle();
    expect(result!['type'], 'Bicycle');
    expect(result!['registration'], 'QA-ONLY');
    expect(result!['manufacturer'], '');
  });

  testWidgets('legacy make remains available in the manufacturer field',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
      body: RiderVehicleEditor(source: {'make': 'QA manufacturer'}),
    )));
    expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        'QA manufacturer');
  });
}
