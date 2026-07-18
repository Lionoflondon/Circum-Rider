import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider profile contact identity rows are read only', () {
    final source =
        File('lib/app/account/view/account_details.dart').readAsStringSync();
    final emailBlock = source.substring(
      source.indexOf('Widget email()'),
      source.indexOf('Widget phone()'),
    );
    final phoneBlock = source.substring(
      source.indexOf('Widget phone()'),
      source.indexOf('Widget _readOnlyContactRow'),
    );

    expect(emailBlock, contains('_readOnlyContactRow'));
    expect(phoneBlock, contains('_readOnlyContactRow'));
    expect(emailBlock, isNot(contains('TextButton')));
    expect(phoneBlock, isNot(contains('TextButton')));
    expect(emailBlock, isNot(contains('onPressed')));
    expect(phoneBlock, isNot(contains('onPressed')));
    expect(emailBlock, isNot(contains('keyboard_arrow_right')));
    expect(phoneBlock, isNot(contains('keyboard_arrow_right')));
  });

  test('Personal Details does not impersonate authentication updates', () {
    final source = File('lib/app/rider_shell/rider_profile_details_view.dart')
        .readAsStringSync();

    expect(source, contains("_field(_phone, 'Phone',"));
    expect(source, contains("_field(_email, 'Email',"));
    expect(source, contains('readOnly: true'));
    expect(source, isNot(contains("'phoneNumber': _phone.text")));
    expect(source, isNot(contains("'email': _email.text")));
  });

  test('Rider profile navigation avoids the legacy account editor', () {
    final profile =
        File('lib/app/rider_shell/rider_profile_view.dart').readAsStringSync();
    final details = File('lib/app/rider_shell/rider_profile_details_view.dart')
        .readAsStringSync();
    final verification =
        File('lib/app/verification/view/verification.dart').readAsStringSync();

    expect(profile, contains('RiderPersonalDetailsView'));
    expect(profile, isNot(contains('AccountDetails')));
    expect(details, isNot(contains('AccountDetails')));
    expect(verification, contains('RiderPersonalDetailsView'));
    expect(verification, isNot(contains('AccountDetails')));
  });
}
