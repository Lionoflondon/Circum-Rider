import 'dart:math';

import 'package:circum_rider/app/authentication/apple_auth_nonce.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Apple nonce is generated at the requested length', () {
    final nonce = generateAppleAuthNonce(length: 32, random: Random(7));

    expect(nonce, hasLength(32));
    expect(nonce, matches(RegExp(r'^[A-Za-z0-9._-]+$')));
  });

  test('Apple sends SHA-256 nonce while Firebase receives raw nonce', () {
    expect(
      sha256Nonce('test-nonce'),
      'ed04c4e9ea6c49cf9ceb39098787c5b9842524f96b07ef45305476a11caec9b4',
    );
  });
}
