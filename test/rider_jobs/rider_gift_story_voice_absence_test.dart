import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider has no Gift Story voice playback surface or dependency', () {
    final screen = File(
      'lib/app/rider_jobs/rider_job_offer_screen.dart',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(
      File('lib/app/rider_jobs/rider_gift_voice_player.dart').existsSync(),
      isFalse,
    );
    expect(screen, isNot(contains('RiderGiftVoicePlayer')));
    expect(screen, isNot(contains("raw['voiceNote']")));
    expect(screen, contains('_AcceptedBottomPanel('));
    expect(pubspec, isNot(contains('just_audio:')));
  });
}
