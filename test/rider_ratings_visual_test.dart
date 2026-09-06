import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circum_rider/app/ratings/rider_appreciation.dart';

void main() {
  testWidgets('Rider sees feedback, category, count and report action',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      for (final family in ['Roboto', 'monospace']) {
        await (FontLoader(family)
              ..addFont(rootBundle
                  .load('assets/fonts/OpenSans/OpenSans-Regular.ttf')))
            .load();
      }
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    });
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RepaintBoundary(
                key: key,
                child: RiderAppreciationSurface(
                  rating: const {
                    'ratingId': 'test',
                    'deliveryId': 'test',
                    'starRating': 5,
                    'feedbackText': 'Very careful and professional.',
                    'deliveryCategories': ['Health+', 'Scheduled']
                  },
                  tip: const {},
                  earnings: const {
                    'averageRating': 4.8,
                    'totalRatings': 12,
                    'lastDeliveryFare': 99
                  },
                  onContinue: () {},
                )))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Report feedback'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Health+ + Scheduled'), findsOneWidget);
    expect(find.text('£99.00'), findsNothing);
    await tester.runAsync(() async {
      final picture = await (key.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final output = File(
          "${Platform.environment['RATING_VISUAL_OUTPUT'] ?? '${Directory.systemTemp.path}/circum-rating-visuals'}/rider-feedback.png");
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
    await tester.tap(find.text('Report feedback'));
    await tester.pumpAndSettle();
    expect(find.text('Abusive or threatening'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('small Rider screen handles larger text and moderated feedback',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!),
      home: Scaffold(
          body: RiderAppreciationSurface(
        rating: const {
          'ratingId': 'test',
          'starRating': 1,
          'hiddenByAdmin': true,
          'feedbackText': 'Hidden comment',
          'deliveryCategories': ['Health+', 'Scheduled']
        },
        tip: const {},
        earnings: const {'averageRating': 3.5, 'totalRatings': 2},
        onContinue: () {},
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Your delivery feedback'), findsOneWidget);
    expect(find.textContaining('Hidden comment'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Continue'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
