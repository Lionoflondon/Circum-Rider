import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepted Gift flow exposes backend-authorized voice playback only', () {
    final player = File(
      'lib/app/rider_jobs/rider_gift_voice_player.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/app/rider_jobs/rider_job_offer_screen.dart',
    ).readAsStringSync();

    expect(player, contains("httpsCallable('getRiderGiftVoicePlayback')"));
    expect(player, contains("'deliveryId': widget.deliveryId"));
    expect(player, contains('.timeout(_operationTimeout)'));
    expect(player, contains('setUrl(url)'));
    expect(player, isNot(contains('print(')));
    expect(screen, contains("widget.offer.raw['voiceNote'] is Map"));
    expect(
        screen, contains('RiderGiftVoicePlayer(deliveryId: widget.offer.id)'));
  });
}
