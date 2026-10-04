import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circum_rider/app/notifications/rider_notification_entity_view.dart';

void main() {
  testWidgets(
      'cancel is disabled during confirmation and sends exactly the selected request once',
      (tester) async {
    final calls = <String>[];
    final result = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => Scaffold(
                                body: RiderWithdrawalCancelButton(
                                    requestId: 'selected-payout',
                                    cancel: (id) {
                                      calls.add(id);
                                      return result.future;
                                    })))),
                    child: const Text('Open payout'))))));
    await tester.tap(find.text('Open payout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel withdrawal'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this withdrawal?'), findsOneWidget);
    final busy = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Cancelling…'));
    expect(busy.onPressed, isNull);
    await tester.tap(find.text('Cancel withdrawal'));
    await tester.pumpAndSettle();
    expect(calls, ['selected-payout']);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancelling…'))
            .onPressed,
        isNull);
    result.complete();
    await tester.pumpAndSettle();
    expect(find.text('Open payout'), findsOneWidget);
  });
}
