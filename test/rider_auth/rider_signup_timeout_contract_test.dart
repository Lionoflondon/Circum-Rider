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
    expect(
        authBloc,
        matches(RegExp(
            r'\.timeout\(\s*_authOperationTimeout\s*,?\s*\)\s*\)\["phone"\]')));
    expect(authBloc, contains('Future.wait(['));
    expect(authBloc, contains(']).timeout(_authRestoreTimeout)'));
    expect(authBloc, contains('vehicleRegistrationDocumentStatus'));
    expect(authBloc, contains('SharedPreferences.getInstance().timeout'));
    expect(authBloc,
        matches(RegExp(r"setString\('riderId', user.uid\)\s*\.timeout")));
    expect(authBloc, contains("step: 'session_restore_preferences'"));
  });

  test('Rider OTP paths cannot leave completers unresolved forever', () {
    final otpHandler = authBloc.substring(
      authBloc.indexOf('if (event is RequestForOTP)'),
      authBloc.indexOf('if (event is VerifySentCode)'),
    );
    expect(authBloc, contains("TimeoutException('phone_otp_send')"));
    expect(authBloc, contains("TimeoutException('phone_otp_request')"));
    expect(
        authBloc, contains('completer.future.timeout(_authOperationTimeout)'));
    expect(otpHandler, contains('if (!completer.isCompleted)'));
    expect(otpHandler, contains("step: 'request_phone_otp'"));
    expect(otpHandler,
        contains('Verification code could not be sent. Try again.'));
    expect(otpHandler, isNot(contains("e.toString().split(':').last.trim()")));
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
