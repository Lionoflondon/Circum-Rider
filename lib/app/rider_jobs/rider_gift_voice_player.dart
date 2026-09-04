import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class RiderGiftVoicePlayer extends StatefulWidget {
  const RiderGiftVoicePlayer({
    super.key,
    required this.deliveryId,
    this.functions,
  });

  final String deliveryId;
  final FirebaseFunctions? functions;

  @override
  State<RiderGiftVoicePlayer> createState() => _RiderGiftVoicePlayerState();
}

class _RiderGiftVoicePlayerState extends State<RiderGiftVoicePlayer> {
  static const _operationTimeout = Duration(seconds: 12);
  late final AudioPlayer _player;
  bool _loading = false;
  bool _playing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing =
          state.playing && state.processingState != ProcessingState.completed;
      if (_playing != playing) setState(() => _playing = playing);
    });
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading) return;
    if (_playing) {
      await _player.pause();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await (widget.functions ?? FirebaseFunctions.instance)
          .httpsCallable('getRiderGiftVoicePlayback')
          .call(<String, dynamic>{'deliveryId': widget.deliveryId}).timeout(
              _operationTimeout);
      final data = Map<String, dynamic>.from(result.data as Map);
      final url = '${data['playbackUrl'] ?? ''}'.trim();
      if (url.isEmpty) throw StateError('Voice note unavailable.');
      await _player.setUrl(url).timeout(_operationTimeout);
      await _player.play();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'The voice note could not be played. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Gift voice note',
      button: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF171B24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            IconButton(
              key: const Key('rider_gift_voice_toggle'),
              onPressed: _loading ? null : _toggle,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gift voice note',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  Text(
                    _error ??
                        (_playing
                            ? 'Playing — for this accepted delivery only'
                            : 'Play the Sender’s delivery note'),
                    style: TextStyle(
                      color: _error == null
                          ? Colors.white70
                          : const Color(0xFFFF8A8A),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
