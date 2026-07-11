import 'dart:io';

import 'package:circum_rider/app/authentication/rider_auth_error.dart';
import 'package:circum_rider/app/onboarding/view/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('complete existing-account text is a tappable semantic control',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExistingRiderSignInLink(onPressed: () => tapped = true),
      ),
    ));

    final link = find.byKey(const Key('existing_rider_sign_in'));
    expect(link, findsOneWidget);
    expect(find.text('Already have an account? Sign in'), findsOneWidget);
    await tester.tap(link);
    expect(tapped, isTrue);
  });

  test('Rider entry and registration are email-only', () {
    final entry =
        File('lib/app/onboarding/view/onboarding.dart').readAsStringSync();
    final signup =
        File('lib/app/authentication/view/signup_form.dart').readAsStringSync();
    expect(entry, contains("title: 'What\\'s your email?'"));
    expect(entry, contains("label: 'Enter your email'"));
    expect(entry, isNot(contains('phone number or email')));
    expect(signup, isNot(contains("label: 'Mobile number'")));
  });

  test('Rider Hosting prevents stale authentication shell assets', () {
    final hosting = File('firebase.json').readAsStringSync();
    expect(hosting, contains('"source": "/index.html"'));
    expect(hosting, contains('"source": "/main.dart.js"'));
    expect(hosting, contains('"source": "/flutter_service_worker.js"'));
    expect(hosting, contains('no-cache, no-store, must-revalidate'));
  });

  test('sign-in form exposes email, password, reset and account navigation',
      () {
    final source =
        File('lib/app/authentication/view/signin_form.dart').readAsStringSync();
    expect(source, contains("AppText.text('Email'"));
    expect(source, contains("AppText.text('Password'"));
    expect(source, contains("AppText.text('Forgot password?'"));
    expect(source, contains('Back to create account'));
    expect(source, contains('SignInWithEmail('));
    expect(source, contains('state.password!.isNotEmpty'));
    expect(source, isNot(contains('state.password!.length >= 8')));
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
