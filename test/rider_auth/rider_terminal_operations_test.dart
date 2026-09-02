import 'dart:async';

import 'package:circum_rider/app/authentication/rider_terminal_operations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('email verification', () {
    test('completes verified bootstrap', () async {
      var bootstrapped = false;
      final verified = await runRiderEmailVerification(
        reload: () async {},
        isVerified: () => true,
        completeVerifiedBootstrap: () async => bootstrapped = true,
        timeout: const Duration(seconds: 1),
      );
      expect(verified, isTrue);
      expect(bootstrapped, isTrue);
    });

    test('returns terminal unverified state without bootstrapping', () async {
      var bootstrapped = false;
      final verified = await runRiderEmailVerification(
        reload: () async {},
        isVerified: () => false,
        completeVerifiedBootstrap: () async => bootstrapped = true,
        timeout: const Duration(seconds: 1),
      );
      expect(verified, isFalse);
      expect(bootstrapped, isFalse);
    });

    test('maps reload, bootstrap, and timeout failures safely', () async {
      Future<void> expectSafe(Future<void> Function() operation) async {
        await expectLater(
          operation(),
          throwsA(
            isA<RiderOperationFailure>().having(
              (failure) => failure.safeMessage,
              'safeMessage',
              isNot(contains('provider-secret')),
            ),
          ),
        );
      }

      await expectSafe(
        () async => runRiderEmailVerification(
          reload: () async => throw Exception('provider-secret'),
          isVerified: () => false,
          completeVerifiedBootstrap: () async {},
          timeout: const Duration(seconds: 1),
        ),
      );
      await expectSafe(
        () async => runRiderEmailVerification(
          reload: () async {},
          isVerified: () => true,
          completeVerifiedBootstrap: () async =>
              throw Exception('provider-secret'),
          timeout: const Duration(seconds: 1),
        ),
      );
      await expectSafe(
        () async => runRiderEmailVerification(
          reload: () => Completer<void>().future,
          isVerified: () => false,
          completeVerifiedBootstrap: () async {},
          timeout: const Duration(milliseconds: 1),
        ),
      );
    });
  });

  test('OTP failures are action-specific and never expose provider text', () {
    expect(
      riderOtpFailureMessage('invalid-verification-code'),
      contains('not correct'),
    );
    expect(riderOtpFailureMessage('session-expired'), contains('expired'));
    expect(riderOtpFailureMessage('quota-exceeded'), contains('Too many'));
    expect(riderOtpFailureMessage('too-many-requests'), contains('Too many'));
    expect(
      riderOtpFailureMessage('network-request-failed'),
      contains('connection'),
    );
    expect(
      riderOtpFailureMessage('provider-secret'),
      isNot(contains('provider-secret')),
    );
  });

  group('sign out', () {
    test('success clears the local session', () async {
      var cleared = false;
      final result = await runRiderSignOut(
        signOut: () async {},
        clearLocalSession: () async => cleared = true,
        timeout: const Duration(seconds: 1),
      );
      expect(result.remoteSignedOut, isTrue);
      expect(result.localCleanupCompleted, isTrue);
      expect(cleared, isTrue);
    });

    test('remote failure still attempts sensitive local cleanup', () async {
      var cleared = false;
      final result = await runRiderSignOut(
        signOut: () async => throw Exception('remote failure'),
        clearLocalSession: () async => cleared = true,
        timeout: const Duration(seconds: 1),
      );
      expect(result.remoteSignedOut, isFalse);
      expect(result.localCleanupCompleted, isTrue);
      expect(cleared, isTrue);
    });

    test('remote timeout and cleanup failure both terminate', () async {
      final result = await runRiderSignOut(
        signOut: () => Completer<void>().future,
        clearLocalSession: () async => throw Exception('cleanup failure'),
        timeout: const Duration(milliseconds: 1),
      );
      expect(result.remoteSignedOut, isFalse);
      expect(result.localCleanupCompleted, isFalse);
    });
  });

  group('account closure', () {
    test('reauthenticates, confirms, and closes in order', () async {
      final stages = <String>[];
      final closed = await runRiderAccountClosure(
        reauthenticate: () async => stages.add('reauth'),
        confirmClosure: () async {
          stages.add('confirm');
          return true;
        },
        closeAccount: () async => stages.add('close'),
        timeout: const Duration(seconds: 1),
      );
      expect(closed, isTrue);
      expect(stages, ['reauth', 'confirm', 'close']);
    });

    test('cancel does not call account closure', () async {
      var closeCalled = false;
      final closed = await runRiderAccountClosure(
        reauthenticate: () async {},
        confirmClosure: () async => false,
        closeAccount: () async => closeCalled = true,
        timeout: const Duration(seconds: 1),
      );
      expect(closed, isFalse);
      expect(closeCalled, isFalse);
    });

    test(
      'reauth and callable failures or timeouts are customer-safe',
      () async {
        Future<void> expectSafe(Future<bool> Function() operation) async {
          await expectLater(
            operation(),
            throwsA(
              isA<RiderOperationFailure>().having(
                (failure) => failure.safeMessage,
                'safeMessage',
                isNot(contains('provider-secret')),
              ),
            ),
          );
        }

        await expectSafe(
          () => runRiderAccountClosure(
            reauthenticate: () async => throw Exception('provider-secret'),
            confirmClosure: () async => true,
            closeAccount: () async {},
            timeout: const Duration(seconds: 1),
          ),
        );
        await expectSafe(
          () => runRiderAccountClosure(
            reauthenticate: () => Completer<void>().future,
            confirmClosure: () async => true,
            closeAccount: () async {},
            timeout: const Duration(milliseconds: 1),
          ),
        );
        await expectSafe(
          () => runRiderAccountClosure(
            reauthenticate: () async {},
            confirmClosure: () async => true,
            closeAccount: () async => throw Exception('provider-secret'),
            timeout: const Duration(seconds: 1),
          ),
        );
        await expectSafe(
          () => runRiderAccountClosure(
            reauthenticate: () async {},
            confirmClosure: () async => true,
            closeAccount: () => Completer<void>().future,
            timeout: const Duration(milliseconds: 1),
          ),
        );
      },
    );
  });
}
