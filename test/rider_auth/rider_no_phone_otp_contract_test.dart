import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final onboarding = File(
    'lib/app/onboarding/view/onboarding.dart',
  ).readAsStringSync();
  final authBloc = File(
    'lib/app/authentication/bloc/auth_bloc.dart',
  ).readAsStringSync();
  test('Rider signup is email-first and never gates on phone OTP', () {
    final signup = authBloc.substring(
      authBloc.indexOf('on<SignUpWithEmail>'),
      authBloc.indexOf('on<UpdatePhoneNumber>'),
    );
    expect(signup, contains('createUserWithEmailAndPassword'));
    expect(signup, isNot(contains('add(SendPhoneOtp())')));
    expect(onboarding, isNot(contains('_RiderAuthStep.phoneOtp')));
    expect(onboarding, isNot(contains('Verify your mobile')));
  });
}
