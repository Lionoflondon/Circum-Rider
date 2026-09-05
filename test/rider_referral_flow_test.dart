import 'dart:async';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circum_rider/app/referrals/rider_referral.dart';
import 'package:circum_rider/app/referrals/rider_referral_view.dart';

void main() {
  test('optional referral normalizes and reports every non-blocking outcome',
      () async {
    var calls = 0;
    Future<String> attach(String code) async {
      calls++;
      expect(code, 'ABC123');
      return 'applied';
    }

    expect(await applyRiderReferral(code: '', attach: attach),
        'Rider account created.');
    expect(calls, 0);
    expect(await applyRiderReferral(code: ' a-b c123 ', attach: attach),
        riderReferralMessage('applied'));
    for (final status in [
      'already_attached',
      'rejected_self_referral',
      'not_found',
      'invalid',
      'unknown_error'
    ]) {
      expect(
          await applyRiderReferral(code: 'ABC123', attach: (_) async => status),
          riderReferralMessage(status));
    }
    expect(
        await applyRiderReferral(
            code: 'ABC123', attach: (_) => Future.error(StateError('offline'))),
        riderReferralMessage('unknown_error'));
    expect(
        await applyRiderReferral(
            code: 'ABC123',
            attach: (_) => Completer<String>().future,
            timeout: const Duration(milliseconds: 1)),
        riderReferralMessage('timeout'));
    expect(normalizeRiderReferral('a' * 40), 'A' * 24);
  });
  test('all required visible messages remain exact', () {
    expect(riderReferralMessage('applied'),
        'Rider account created. Referral code applied. Rewards unlock after approval and your first completed delivery.');
    expect(riderReferralMessage('not_found'),
        'Rider account created, but that referral code was not found.');
    expect(riderReferralMessage('rejected_self_referral'),
        'Rider account created, but your own referral code cannot be used.');
    expect(riderReferralMessage('already_attached'),
        'Rider account created. Referral already linked.');
    expect(riderReferralMessage('timeout'),
        'Rider account created, but referral verification timed out. Try again from Rider Referrals.');
    expect(riderReferralMessage('unknown_error'),
        'Rider account created, but referral code could not be applied.');
  });
  testWidgets('signed-out panel never requests a code', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RiderReferralPanel(
                signedIn: false,
                loadCode: () async {
                  calls++;
                  return {};
                }))));
    expect(calls, 0);
    expect(find.text('Sign in as a Rider to use referrals.'), findsOneWidget);
  });
  testWidgets('approved code loads with real code link and copy/share actions',
      (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RiderReferralPanel(
                signedIn: true, loadCode: () => pending.future))));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete({
      'referralCode': 'R123',
      'referralLink': 'https://circumuk.com/rider?referral=R123'
    });
    await tester.pumpAndSettle();
    expect(find.text('R123'), findsOneWidget);
    expect(find.text('Copy code'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text(riderReferralRewardCopy), findsOneWidget);
  });
  testWidgets('approval denial is visible and retry attachment stays available',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RiderReferralPanel(
                signedIn: true,
                loadCode: () => Future.error(FirebaseFunctionsException(
                    code: 'permission-denied', message: 'approval required')),
                attachCode: (_) async => 'not_found'))));
    await tester.pumpAndSettle();
    expect(find.text('Rider approval is required to share a referral code.'),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), 'BAD');
    await tester.tap(find.text('Apply referral code'));
    await tester.pumpAndSettle();
    expect(find.text(riderReferralMessage('not_found')), findsOneWidget);
  });
  test(
      'signup wiring attaches only after profile and wallet bootstrap; restores fail closed',
      () {
    final source =
        File('lib/app/authentication/bloc/auth_bloc.dart').readAsStringSync();
    final signup = source.substring(
        source.indexOf('on<SignUpWithEmail>'),
        source.indexOf("} on FirebaseAuthException",
            source.indexOf('on<SignUpWithEmail>')));
    expect(signup.indexOf('await runRiderAuthBootstrap'),
        lessThan(signup.indexOf('await applyRiderReferral')));
    expect(signup, contains("'program': 'rider'"));
    expect(source, contains("httpsCallable('updateRiderProfile')"));
    expect(source, contains("cause.code == 'permission-denied'"));
    expect(source, contains('if (!riderAccessVerified)'));
    expect(
        source,
        matches(RegExp(
            r'firebaseAuthenticationSucceeded\s*&&\s*riderAccessVerified')));
    expect(File('lib/app/onboarding/view/onboarding.dart').readAsStringSync(),
        contains('REFERRAL CODE (OPTIONAL)'));
  });
}
