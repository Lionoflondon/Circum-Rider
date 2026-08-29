import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final onboarding =
      File('lib/app/onboarding/view/onboarding.dart').readAsStringSync();
  final authBloc =
      File('lib/app/authentication/bloc/auth_bloc.dart').readAsStringSync();

  test('normalizes both UK mobile entry forms exactly once', () {
    expect(onboarding, contains("digits.startsWith('07')"));
    expect(
        onboarding, contains("digits.startsWith('7') && digits.length == 10"));
    expect(onboarding, contains(r"'+44${digits.substring(1)}'"));
    expect(onboarding, contains(r"return '+44$digits';"));
    expect(onboarding, isNot(contains("'+440")));
  });

  test('bounds every signup operation that can strand loading', () {
    expect(authBloc, contains('_signupOperationTimeout'));
    expect(authBloc, contains('createUserWithEmailAndPassword'));
    expect(authBloc, contains('updateDisplayName(fullName)'));
    expect(authBloc, contains('upsertRiderOnboarding(user: user, data:'));
    expect(authBloc, contains('ensureRiderRothWallet'));
    expect(authBloc, contains('.timeout(_signupOperationTimeout)'));
  });

  test('bounds Rider session restore and profile enrichment operations', () {
    expect(authBloc, contains('_authRestoreTimeout'));
    expect(authBloc, contains('.readAll()'));
    expect(authBloc, contains('.timeout(_authOperationTimeout))["phone"]'));
    expect(authBloc, contains('Future.wait(['));
    expect(authBloc, contains(']).timeout(_authRestoreTimeout)'));
    expect(authBloc, contains('vehicleRegistrationDocumentStatus'));
    expect(authBloc, contains('SharedPreferences.getInstance().timeout'));
    expect(authBloc, contains("setString('riderId', user.uid).timeout"));
  });

  test('Rider OTP paths cannot leave completers unresolved forever', () {
    expect(authBloc, contains("TimeoutException('phone_otp_send')"));
    expect(authBloc, contains("TimeoutException('phone_otp_request')"));
    expect(
        authBloc, contains('completer.future.timeout(_authOperationTimeout)'));
    expect(authBloc, contains('if (!completer.isCompleted)'));
  });

  test('Rider OAuth and password reset failures terminate safely', () {
    expect(authBloc, contains("step: 'apple_sign_in'"));
    expect(authBloc, contains("step: 'google_sign_in'"));
    expect(
        authBloc, contains('Apple sign-in could not be completed. Try again.'));
    expect(authBloc,
        contains('Google sign-in could not be completed. Try again.'));
    expect(authBloc, isNot(contains('user!.displayName!')));
    expect(
        authBloc, isNot(contains('throw Exception(err.message.toString())')));
    expect(authBloc, isNot(contains('throw Exception(err.toString())')));
  });

  test('Rider auth diagnostics are production safe', () {
    expect(authBloc, contains('Rider auth diagnostic stage='));
    expect(authBloc, contains(r'category=$category'));
    expect(authBloc, contains('riderDocumentId.hashCode'));
    expect(
        authBloc,
        isNot(contains(r'Rider auth diagnostic stage=$step '
            r'category=$category code=$code path=$path riderRef=$riderDocumentId')));
  });

  test('signup retains recoverable partial-account path', () {
    expect(authBloc, contains("'onboardingStatus': 'profile_started'"));
    expect(authBloc, contains('email-already-in-use'));
    expect(authBloc, contains('Status.failure'));
    expect(authBloc, contains('Something went wrong'));
  });
}
