import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider Web persists auth without the hanging IndexedDB provider', () {
    final source = File(
      'packages/firebase_auth_web_session/lib/src/interop/auth.dart',
    ).readAsStringSync();

    final configuredPersistences = source.substring(
      source.indexOf('final List<JSAny?> persistences'),
      source.indexOf('return Auth.getInstance'),
    );

    expect(configuredPersistences, contains('browserLocalPersistence'));
    expect(
        configuredPersistences, isNot(contains('indexedDBLocalPersistence')));
    expect(
        configuredPersistences, isNot(contains('browserSessionPersistence')));
  });
}
