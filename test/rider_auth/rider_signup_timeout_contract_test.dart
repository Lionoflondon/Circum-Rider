import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final onboarding =
      File('lib/app/onboarding/view/onboarding.dart').readAsStringSync();
  final authBloc =
      File('lib/app/authentication/bloc/auth_bloc.dart').readAsStringSync();

  test('signup contains no phone OTP entry or normalization', () {
    expect(onboarding, isNot(contains('PhoneNumberChanged')));
    expect(onboarding, isNot(contains('VerifyPhoneOtp')));
    expect(onboarding, isNot(contains('ResendPhoneOtp')));
    expect(onboarding, isNot(contains("digits.startsWith('07')")));
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
    expect(authBloc, contains("step: 'session_restore_preferences'"));
  });

  test('Rider auth bloc has no phone OTP provider paths', () {
    expect(authBloc, isNot(contains('verifyPhoneNumber')));
    expect(authBloc, isNot(contains('PhoneAuthProvider.credential')));
    expect(authBloc, isNot(contains('SendPhoneOtp')));
    expect(authBloc, isNot(contains('VerifyPhoneOtp')));
    expect(authBloc, isNot(contains('RequestForOTP')));
    expect(authBloc, isNot(contains('VerifySentCode')));
  });

  test('Rider OAuth and password reset failures terminate safely', () {
    expect(authBloc, contains("step: 'apple_sign_in'"));
    expect(authBloc, contains("step: 'google_sign_in'"));
    expect(
        authBloc, contains('Apple sign-in could not be completed. Try again.'));
    expect(authBloc, contains('nonce: sha256Nonce(rawNonce)'));
    expect(authBloc, contains('rawNonce: rawNonce'));
    expect(
      authBloc,
      isNot(contains('accessToken: appleCredential.authorizationCode')),
    );
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
    expect(
      authBloc,
      contains("We couldn't create your account. Please try again."),
    );
    expect(
      authBloc,
      contains(
        'Your account was created, but setup did not finish. Try again to continue.',
      ),
    );
    expect(authBloc, isNot(contains('Something went wrong')));
  });

  test('session restore retries missing Rider bootstrap idempotently', () {
    expect(authBloc, contains('!records[0].exists && !records[1].exists'));
    expect(authBloc, contains('ensureRiderOnboardingStarted('));
    expect(authBloc, contains('riderOnboardingNeedsProfileStart(status)'));
  });
}
