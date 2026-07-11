import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider profile exposes secure account closure flow', () {
    final profile = File(
      '${Directory.current.path}/lib/app/rider_shell/rider_profile_view.dart',
    ).readAsStringSync();

    expect(profile, contains('Close Account'));
    expect(profile,
        contains('Permanently delete your Circum account and personal data.'));
    expect(profile, contains('Close your Circum account?'));
    expect(profile, contains('Type DELETE to confirm.'));
    expect(profile, contains("httpsCallable('closeCircumAccount')"));
    expect(profile, contains("'accountType': 'rider'"));
    expect(profile, contains('reauthenticateWithCredential'));
    expect(profile, contains('reauthenticateWithProvider'));
    expect(profile, isNot(contains("storage.write(key: 'password'")));
  });
}
