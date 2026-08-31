import 'dart:async';

import 'package:circum_rider/app/authentication/rider_auth_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile-start recovery skips stages that already advanced', () {
    expect(riderOnboardingNeedsProfileStart(null), isTrue);
    expect(riderOnboardingNeedsProfileStart('not_started'), isTrue);
    expect(riderOnboardingNeedsProfileStart('account_created'), isTrue);
    expect(riderOnboardingNeedsProfileStart('profile_started'), isFalse);
    expect(riderOnboardingNeedsProfileStart('phone_verified'), isFalse);
    expect(riderOnboardingNeedsProfileStart('profile_complete'), isFalse);
  });

  test('bootstrap completes each authority operation once in order', () async {
    final calls = <RiderBootstrapStage>[];

    await runRiderAuthBootstrap(
      updateDisplayName: () async => calls.add(RiderBootstrapStage.displayName),
      initializeProfile: () async => calls.add(RiderBootstrapStage.profile),
      initializeRothWallet: () async =>
          calls.add(RiderBootstrapStage.rothWallet),
    );

    expect(calls, RiderBootstrapStage.values);
  });

  test('bootstrap reports the first failed authority operation', () async {
    var rothCalls = 0;

    await expectLater(
      runRiderAuthBootstrap(
        updateDisplayName: () async {},
        initializeProfile: () async => throw StateError('profile unavailable'),
        initializeRothWallet: () async => rothCalls++,
      ),
      throwsA(
        isA<RiderBootstrapException>().having(
          (error) => error.stage,
          'stage',
          RiderBootstrapStage.profile,
        ),
      ),
    );
    expect(rothCalls, 0);
  });

  test('bootstrap has one total deadline and identifies timeout stage',
      () async {
    final never = Completer<void>();

    await expectLater(
      runRiderAuthBootstrap(
        timeout: const Duration(milliseconds: 20),
        updateDisplayName: () async {},
        initializeProfile: () => never.future,
        initializeRothWallet: () async {},
      ),
      throwsA(
        isA<RiderBootstrapException>()
            .having(
              (error) => error.stage,
              'stage',
              RiderBootstrapStage.profile,
            )
            .having((error) => error.cause, 'cause', isA<TimeoutException>()),
      ),
    );
  });

  test('idempotent retry reruns the same authority sequence safely', () async {
    var profileCalls = 0;
    var rothCalls = 0;

    Future<void> bootstrap() => runRiderAuthBootstrap(
          updateDisplayName: () async {},
          initializeProfile: () async => profileCalls++,
          initializeRothWallet: () async => rothCalls++,
        );

    await bootstrap();
    await bootstrap();

    expect(profileCalls, 2);
    expect(rothCalls, 2);
  });
}
