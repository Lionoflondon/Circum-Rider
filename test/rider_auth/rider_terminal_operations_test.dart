import 'dart:async';

import 'package:circum_rider/app/authentication/rider_terminal_operations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'email auth accepts native completion after the old 20 second deadline',
      (tester) async {
    final native = Completer<String>();
    String? result;
    Object? failure;
    runRiderAuthentication(native.future).then<void>(
      (value) {
        result = value;
      },
      onError: (Object error) {
        failure = error;
      },
    );
    Timer(const Duration(seconds: 25), () => native.complete('authenticated'));
    await tester.pump(const Duration(seconds: 25));
    expect(result, 'authenticated');
    expect(failure, isNull);
  });
  testWidgets('email authentication still has a finite network deadline',
      (tester) async {
    final native = Completer<String>();
    Object? failure;
    runRiderAuthentication(native.future).then<void>(
      (_) {},
      onError: (Object error) {
        failure = error;
      },
    );
    await tester.pump(const Duration(seconds: 61));
    expect(failure, isA<TimeoutException>());
    native.complete('late');
    await tester.pump();
  });
  test('sign-out during email reload discards verification and bootstrap',
      () async {
    final reload = Completer<void>();
    var current = true;
    var bootstrapped = false;
    final verification = runRiderEmailVerification(
      reload: () => reload.future,
      isVerified: () => true,
      refreshVerifiedToken: () async {},
      completeVerifiedBootstrap: () async {
        bootstrapped = true;
      },
      isCurrentSession: () => current,
      timeout: const Duration(seconds: 1),
    );
    current = false;
    reload.complete();
    expect(await verification, isFalse);
    expect(bootstrapped, isFalse);
  });
  test('stale verification failure does not overwrite a signed-out session',
      () async {
    final reload = Completer<void>();
    var current = true;
    final verification = runRiderEmailVerification(
      reload: () => reload.future,
      isVerified: () => true,
      refreshVerifiedToken: () async {},
      completeVerifiedBootstrap: () async {},
      isCurrentSession: () => current,
      timeout: const Duration(seconds: 1),
    );
    current = false;
    reload.completeError(StateError('old session'));
    expect(await verification, isFalse);
  });
  group('bounded operation guard', () {
    test('returns successful operation result', () async {
      final result = await runBoundedRiderOperation(
        Future.value('done'),
        timeout: const Duration(seconds: 1),
      );
      expect(result, 'done');
    });

    test('terminates a never-completing operation', () async {
      await expectLater(
        runBoundedRiderOperation(
          Completer<void>().future,
          timeout: const Duration(milliseconds: 1),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  group('email verification', () {
    test('refreshes verified claims before protected bootstrap', () async {
      final order = <String>[];
      final verified = await runRiderEmailVerification(
        reload: () async {
          order.add('reload');
        },
        isVerified: () {
          order.add('verified');
          return true;
        },
        refreshVerifiedToken: () async {
          order.add('refresh');
        },
        completeVerifiedBootstrap: () async {
          order.add('bootstrap');
        },
        timeout: const Duration(seconds: 1),
      );
      expect(verified, isTrue);
      expect(order, ['reload', 'verified', 'refresh', 'bootstrap']);
    });
    test('failed claim refresh cannot establish verified onboarding', () async {
      var bootstrapped = false;
      await expectLater(
          runRiderEmailVerification(
            reload: () async {},
            isVerified: () => true,
            refreshVerifiedToken: () async {
              throw StateError('token unavailable');
            },
            completeVerifiedBootstrap: () async {
              bootstrapped = true;
            },
            timeout: const Duration(seconds: 1),
          ),
          throwsA(isA<RiderOperationFailure>()));
      expect(bootstrapped, isFalse);
    });

    test('returns terminal unverified state without bootstrapping', () async {
      var bootstrapped = false;
      var refreshed = false;
      final verified = await runRiderEmailVerification(
        reload: () async {},
        isVerified: () => false,
        refreshVerifiedToken: () async {
          refreshed = true;
        },
        completeVerifiedBootstrap: () async => bootstrapped = true,
        timeout: const Duration(seconds: 1),
      );
      expect(verified, isFalse);
      expect(bootstrapped, isFalse);
      expect(refreshed, isFalse);
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
          refreshVerifiedToken: () async {},
          completeVerifiedBootstrap: () async {},
          timeout: const Duration(seconds: 1),
        ),
      );
      await expectSafe(
        () async => runRiderEmailVerification(
          reload: () async {},
          isVerified: () => true,
          refreshVerifiedToken: () async {},
          completeVerifiedBootstrap: () async =>
              throw Exception('provider-secret'),
          timeout: const Duration(seconds: 1),
        ),
      );
      await expectSafe(
        () async => runRiderEmailVerification(
          reload: () => Completer<void>().future,
          isVerified: () => false,
          refreshVerifiedToken: () async {},
          completeVerifiedBootstrap: () async {},
          timeout: const Duration(milliseconds: 1),
        ),
      );
    });
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
