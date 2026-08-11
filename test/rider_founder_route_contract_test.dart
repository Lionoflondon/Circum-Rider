import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical Founder access can restore the operational Rider shell', () {
    final router = File('lib/app.dart').readAsStringSync();

    expect(
      router,
      contains(
        'internalAccess ||\n'
        '                (state.authenticatedStatus ==',
      ),
    );
    expect(
      router,
      isNot(
        contains(
          'state.authenticatedStatus == AuthenticatedStatus.authenticated &&\n'
          '            (internalAccess ||',
        ),
      ),
    );
  });
}
