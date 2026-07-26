import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider profile contact identity rows are read only', () {
    final source = File('lib/app/rider_shell/rider_profile_details_view.dart')
        .readAsStringSync();
    final phoneField = source.substring(
      source.indexOf("_field(_phone, 'Phone'"),
      source.indexOf("_field(_email, 'Email'"),
    );
    final emailField = source.substring(
      source.indexOf("_field(_email, 'Email'"),
      source.indexOf("_field(_address, 'Home address'"),
    );

    expect(phoneField, contains('readOnly: true'));
    expect(emailField, contains('readOnly: true'));
    expect(phoneField, isNot(contains('TextButton')));
    expect(emailField, isNot(contains('TextButton')));
    expect(phoneField, isNot(contains('onPressed')));
    expect(emailField, isNot(contains('onPressed')));
    expect(phoneField, isNot(contains('keyboard_arrow_right')));
    expect(emailField, isNot(contains('keyboard_arrow_right')));
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

  test('Rider username is platform assigned and read only in the app', () {
    final details = File('lib/app/rider_shell/rider_profile_details_view.dart')
        .readAsStringSync();
    final profile =
        File('lib/app/rider_shell/rider_profile_view.dart').readAsStringSync();

    expect(details, isNot(contains('final _username = TextEditingController')));
    expect(details, isNot(contains("'handle': handle")));
    expect(details, isNot(contains("'username': handle")));
    expect(details, contains("collection('riders')"));
    expect(details, contains("collection('riderProfiles')"));
    expect(
        details, contains('Rider usernames are assigned by Circum operations'));
    expect(details, contains('Awaiting assignment'));
    expect(profile, contains("'handle'"));
    expect(profile, contains("'riderHandle'"));
    expect(profile, contains("'username'"));
    expect(profile, contains('assigned username'));
  });
}
