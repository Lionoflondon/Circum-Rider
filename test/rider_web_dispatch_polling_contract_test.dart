import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restored online state polls only after a usable location', () {
    final source = File('lib/app/home/bloc/home_bloc.dart').readAsStringSync();

    expect(
      source,
      contains(
          'if (locationPayload != null) {\n            add(GetAvailableRequests());'),
    );
    expect(
      RegExp(r'add\(GetAvailableRequests\(\)\);').allMatches(source).length,
      1,
    );
  });

  test('Rider Web declares the current installable Web capability', () {
    final index = File('web/index.html').readAsStringSync();
    expect(index, contains('name="mobile-web-app-capable" content="yes"'));
  });
}
