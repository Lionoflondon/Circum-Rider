import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider Web auth bootstrap uses the SDK readiness contract', () {
    final adapter = File(
      'third_party/firebase_auth_web/lib/src/interop/auth.dart',
    ).readAsStringSync();

    expect(adapter, contains('await jsObject.authStateReady().toDart;'));
    expect(adapter, contains('User.getInstance(jsObject.currentUser)'));
    expect(adapter, isNot(contains('await completer.future;')));
  });
}
