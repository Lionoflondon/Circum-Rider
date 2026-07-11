import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('founder access is token-claim based and never email or client writable',
      () {
    final source = File('lib/app/founder_access/founder_rider_access.dart')
        .readAsStringSync();
    expect(source, contains("claims?['founderRider'] == true"));
    expect(source, isNot(contains('ayojason600@gmail.com')));
    expect(source, isNot(contains('setCustomUserClaims')));
    expect(source, isNot(contains('localStorage')));
  });

  test(
      'session gate preserves normal account states while allowing claim override',
      () {
    final source = File('lib/app.dart').readAsStringSync();
    expect(source, contains('!founder'));
    expect(source, contains('founder ||'));
    expect(source, contains('RiderAccountState.approved'));
  });
}
