import 'dart:io';

import 'package:circum_rider/app/rider_design/rider_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider theme uses the bundled Montserrat hierarchy', () {
    final theme = RiderTypography.theme();

    expect(RiderTypography.heading, 'Montserrat');
    expect(RiderTypography.body, 'Montserrat');
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Montserrat');
    expect(RiderTypography.display().fontWeight, FontWeight.w600);
    expect(RiderTypography.display().letterSpacing, greaterThan(1));
    expect(RiderTypography.section().letterSpacing, lessThan(1));
    expect(RiderTypography.metric().letterSpacing, 0);
  });

  testWidgets('cinematic heading remains bounded on a narrow Rider viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: RiderTypography.theme(),
        home: const Scaffold(
          body: SizedBox(
            width: 280,
            child: RiderCinematicHeading('Navigating to drop-off'),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.text('NAVIGATING TO DROP-OFF'));
    expect(text.style?.fontFamily, 'Montserrat');
    expect(text.style?.fontWeight, FontWeight.w600);
    expect(text.style?.letterSpacing, lessThan(2));
  });

  testWidgets('all Rider ranks retain canonical names and palette', (
    tester,
  ) async {
    for (final rank in const [
      'Agent',
      'Sentinel',
      'Warden',
      'Knight',
      'Veteran',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: RiderTypography.theme(),
          home: Scaffold(
            body: RiderRankProgress(rank: rank, trustPoints: 1500),
          ),
        ),
      );
      expect(find.text(rank.toUpperCase()), findsOneWidget);
    }

    final veteran = tester.widget<Text>(find.text('VETERAN'));
    expect(veteran.style?.color, RiderPalette.amber);
    expect(find.text('1500 TP'), findsOneWidget);
  });

  test('offer and profile typography preserve operational readability', () {
    final offer = File(
      'lib/app/rider_jobs/rider_offer_card.dart',
    ).readAsStringSync();
    final profile = File(
      'lib/app/rider_shell/rider_profile_view.dart',
    ).readAsStringSync();
    final profileDetails = File(
      'lib/app/rider_shell/rider_profile_details_view.dart',
    ).readAsStringSync();

    expect(offer, contains('RiderTypography.display('));
    expect(offer, contains('Accept Delivery'));
    expect(offer, isNot(contains("letterSpacing: 2")));
    expect(profile, contains("'Trust Points'"));
    expect(profile, contains("'\${data.trustPoints} TP'"));
    expect(profile, isNot(contains("'\${data.trustPoints} trust'")));
    expect(profileDetails, contains("'\$current TP'"));
  });

  test('font assets are local and licensed', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: Montserrat'));
    expect(pubspec, contains('Montserrat-Regular.ttf'));
    expect(pubspec, contains('Montserrat-Medium.ttf'));
    expect(pubspec, contains('Montserrat-SemiBold.ttf'));
    expect(File('assets/fonts/Montserrat/OFL.txt').existsSync(), isTrue);
  });
}
