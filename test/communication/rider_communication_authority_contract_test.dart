import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider chat mutations satisfy the canonical idempotency contract', () {
    final source = File(
      'lib/app/communication/rider_communication_service.dart',
    ).readAsStringSync();

    expect(source, contains("httpsCallable('sendCircumMessage')"));
    expect(source, contains("'clientMessageId': 'rider:\${_uuid.v4()}'"));
    expect(source, isNot(contains("collection('chats').add")));
    expect(source, isNot(contains("collection('messages').add")));
  });
}
