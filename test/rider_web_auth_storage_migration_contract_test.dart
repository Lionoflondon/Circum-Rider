import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider Web migrates the temporary session auth record before startup',
      () {
    final index = File('web/index.html').readAsStringSync();

    expect(index, contains("startsWith('firebase:authUser:')"));
    expect(index, contains('localStorage.setItem'));
    expect(
      index.indexOf("startsWith('firebase:authUser:')"),
      lessThan(index.indexOf('flutter_bootstrap.js')),
    );
  });
}
