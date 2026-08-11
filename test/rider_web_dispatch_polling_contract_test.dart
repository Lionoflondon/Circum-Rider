import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offer polling waits for a usable Rider location', () {
    final source = File('lib/app/home/bloc/home_bloc.dart').readAsStringSync();

    expect(
      source,
      contains(
          'if (locationPayload != null) {\n            add(GetAvailableRequests());'),
    );
  });
}
