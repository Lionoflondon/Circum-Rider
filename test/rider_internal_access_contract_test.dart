import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'internal access is token-claim based and never email or client writable',
      () {
    final source =
        File('lib/app/rider_internal_access/rider_internal_access.dart')
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
    expect(source, contains('!internalAccess'));
    expect(source, contains('internalAccess ||'));
    expect(source, contains('RiderAccountState.approved'));
  });
}
