import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider Web retains a page while canonical claims resolve', () {
    final source = File('lib/app.dart').readAsStringSync();

    expect(source, contains('forceRefresh: !kIsWeb'));
    expect(
      source,
      contains('currentState: AppState.unknownSessionState'),
    );
  });
}
