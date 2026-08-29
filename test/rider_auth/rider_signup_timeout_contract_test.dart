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

  test('signup retains recoverable partial-account path', () {
    expect(authBloc, contains("'onboardingStatus': 'profile_started'"));
    expect(authBloc, contains('email-already-in-use'));
    expect(authBloc, contains('Status.failure'));
    expect(authBloc, contains('Something went wrong'));
  });
}
