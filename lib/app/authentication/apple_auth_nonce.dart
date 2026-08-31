import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

const _nonceCharacters =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';

String generateAppleAuthNonce({int length = 32, Random? random}) {
  if (length <= 0) throw ArgumentError.value(length, 'length');
  final generator = random ?? Random.secure();
  return List.generate(
    length,
    (_) => _nonceCharacters[generator.nextInt(_nonceCharacters.length)],
  ).join();
}

String sha256Nonce(String rawNonce) =>
    sha256.convert(utf8.encode(rawNonce)).toString();
