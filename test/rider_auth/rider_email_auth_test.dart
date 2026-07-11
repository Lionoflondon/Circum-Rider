import 'dart:io';

import 'package:circum_rider/app/authentication/rider_auth_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('replacement auth experience is the only active Rider entry', () {
    final entry =
        File('lib/app/onboarding/view/onboarding.dart').readAsStringSync();
    final app = File('lib/app.dart').readAsStringSync();

    expect(app, contains('child: OnboardingView()'));
    expect(entry, contains('Deliver with Circum'));
    expect(entry, contains('Get started'));
    expect(entry, contains('Existing Rider sign in'));
    expect(entry, contains('Create Rider account'));
    expect(entry, contains('Full name'));
    expect(entry, contains('UK mobile number'));
    expect(entry, contains('Verify your mobile'));
    expect(entry, contains('Enable location'));
    expect(entry, isNot(contains("What's your email?")));
    expect(entry, isNot(contains('phone number or email')));
  });

  test('legacy Rider auth presentation files are removed', () {
    expect(
        File('lib/app/authentication/view/signin.dart').existsSync(), isFalse);
    expect(File('lib/app/authentication/view/signin_form.dart').existsSync(),
        isFalse);
    expect(
        File('lib/app/authentication/view/signup.dart').existsSync(), isFalse);
    expect(File('lib/app/authentication/view/signup_form.dart').existsSync(),
        isFalse);
    final source =
        File('lib/app/onboarding/view/onboarding.dart').readAsStringSync();
    expect(source, isNot(contains('SigninView')));
    expect(source, isNot(contains('SignupView')));
  });

  test('Rider Hosting prevents stale authentication shell assets', () {
    final hosting = File('firebase.json').readAsStringSync();
    final index = File('web/index.html').readAsStringSync();
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(hosting, contains('"source": "**"'));
    expect(hosting, contains('"source": "/"'));
    expect(hosting, contains('"source": "/index.html"'));
    expect(hosting, contains('"source": "/flutter_bootstrap.js"'));
    expect(hosting, contains('"source": "/main.dart.js"'));
    expect(hosting, contains('"source": "/flutter_service_worker.js"'));
    expect(hosting, contains('no-cache, no-store, must-revalidate'));
    expect(index, contains('src="flutter_bootstrap.js"'));
    expect(index, isNot(contains('loadEntrypoint')));
    expect(index, isNot(contains('manifest.json')));
    expect(bootstrap, contains('getRegistrations()'));
    expect(bootstrap, contains('registration.unregister()'));
    expect(bootstrap, contains('caches.keys()'));
    expect(bootstrap, contains('caches.delete(cacheName)'));
    expect(bootstrap, contains('serviceWorkerSettings: null'));
    expect(bootstrap, contains("CIRCUM_RIDER_BUILD = 'rider-web-cache-v1'"));
  });

  test('new sign-in form exposes email, password, reset and account navigation',
      () {
    final source =
        File('lib/app/onboarding/view/onboarding.dart').readAsStringSync();
    expect(source, contains("'Welcome back'"));
    expect(source, contains("label: 'Email'"));
    expect(source, contains("label: 'Password'"));
    expect(source, contains("'Forgot password'"));
    expect(source, contains('Back to create account'));
    expect(source, contains('SignInWithEmail('));
    expect(source, contains('ResetPassword(email: email)'));
  });

  test('new registration requires phone OTP, consents and location step', () {
    final source =
        File('lib/app/onboarding/view/onboarding.dart').readAsStringSync();
    expect(source, contains('SignUpWithEmail('));
    expect(source, contains('PhoneNumberChanged'));
    expect(source, contains('VerifyPhoneOtp'));
    expect(source, contains('ResendPhoneOtp'));
    expect(source, contains('Change number'));
    expect(source, contains('Accept the Rider Terms'));
    expect(source, contains('Accept the Privacy Policy'));
    expect(source, contains('legally entitled to work in the UK'));
    expect(source, contains('RequestLocationData'));
    expect(
        source, contains('CompleteRiderApplication(locationEnabled: false)'));
  });

  test('Firebase auth errors have clear customer-safe messages', () {
    expect(RiderAuthError.messageFor('invalid-email'),
        'Enter a valid email address.');
    expect(RiderAuthError.messageFor('wrong-password'),
        'The password is incorrect. Try again or reset it.');
    expect(RiderAuthError.messageFor('invalid-credential'),
        'The email or password is incorrect.');
    expect(RiderAuthError.messageFor('user-not-found'),
        'No Rider account was found for that email.');
    expect(RiderAuthError.messageFor('user-disabled'),
        'This Rider account is disabled. Contact Circum Support.');
    expect(RiderAuthError.messageFor('network-request-failed'),
        'Check your connection and try again.');
    expect(RiderAuthError.messageFor('too-many-requests'),
        'Too many attempts. Wait a moment or reset your password.');
  });

  test('existing sign-in restores Rider document without creating a profile',
      () {
    final bloc =
        File('lib/app/authentication/bloc/auth_bloc.dart').readAsStringSync();
    final handler = bloc.substring(
      bloc.indexOf('on<SignInWithEmail>'),
      bloc.indexOf('on<SignUpWithEmail>'),
    );
    expect(handler, contains("db.collection('riders').doc"));
    expect(handler, contains('RiderAccountStateResolver.resolve'));
    expect(handler, isNot(contains('.set(')));
    expect(handler, isNot(contains('createUserWithEmailAndPassword')));
  });
}
