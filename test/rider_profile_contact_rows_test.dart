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

  test('Rider profile photo reads backend identity and avoids legacy picker UI',
      () {
    final details = File('lib/app/rider_shell/rider_profile_details_view.dart')
        .readAsStringSync();
    final profile =
        File('lib/app/rider_shell/rider_profile_view.dart').readAsStringSync();

    expect(details, contains("collection('riders')"));
    expect(details, contains("collection('riderProfiles')"));
    expect(details, contains("'profileThumbnailUrl'"));
    expect(details, contains("'profilePhotoUrl'"));
    expect(details, contains("'photoURL'"));
    expect(details, contains('UpdateUserProfilePhoto'));
    expect(
        details, contains('This is the photo senders see during deliveries.'));
    expect(details, contains('_showRiderPhotoSourceSheet'));
    expect(details, isNot(contains('showImageBottomSheet')));
    expect(details, isNot(contains("account/view/bottom_sheets/image_bs")));
    expect(profile, contains('Icons.person_rounded'));
    expect(profile,
        isNot(contains('Text(\\n                            initials')));
  });

  test('Rider photo upload uses backend-authoritative identity callable', () {
    final authBloc =
        File('lib/app/authentication/bloc/auth_bloc.dart').readAsStringSync();
    final homeBloc =
        File('lib/app/home/bloc/home_bloc.dart').readAsStringSync();

    expect(authBloc, contains("httpsCallable('submitRiderDocument')"));
    expect(authBloc, contains("'documentType': 'profile_photo'"));
    expect(authBloc, contains("'fileBase64': base64Encode(processed.full)"));
    expect(authBloc, contains("data['fileUrl']"));
    expect(authBloc, isNot(contains('FirebaseStorage')));
    expect(homeBloc.indexOf('profileThumbnailUrl'),
        lessThan(homeBloc.indexOf('profilePhotoUrl')));
    expect(homeBloc, contains(r"'photoURL': '$riderPhoto'"));
  });

  test('Rider username is editable and persisted to backend profile documents',
      () {
    final details = File('lib/app/rider_shell/rider_profile_details_view.dart')
        .readAsStringSync();
    final profile =
        File('lib/app/rider_shell/rider_profile_view.dart').readAsStringSync();

    expect(details, contains("_username.text"));
    expect(details, contains("'handle': handle"));
    expect(details, contains("'username': handle"));
    expect(details, contains("collection('riders')"));
    expect(details, contains("collection('riderProfiles')"));
    expect(details, contains('Your Rider username is saved'));
    expect(profile, contains("'handle'"));
    expect(profile, contains("'riderHandle'"));
    expect(profile, contains("'username'"));
  });
}
