import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider release requests production Apple service environments', () {
    final entitlements =
        File('ios/Runner/RunnerRelease.entitlements').readAsStringSync();

    expect(
        entitlements, contains('<key>com.apple.developer.applesignin</key>'));
    expect(entitlements, contains('<string>Default</string>'));
    expect(
      RegExp(r'<string>production</string>').allMatches(entitlements),
      hasLength(2),
    );
    expect(entitlements, isNot(contains('<string>development</string>')));
  });
}
