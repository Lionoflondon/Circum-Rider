import 'dart:async';

class RiderOperationFailure implements Exception {
  const RiderOperationFailure(this.safeMessage);

  final String safeMessage;
}

Future<T> runBoundedRiderOperation<T>(
  Future<T> operation, {
  required Duration timeout,
}) =>
    operation.timeout(timeout);

Future<bool> runRiderEmailVerification({
  required Future<void> Function() reload,
  required bool Function() isVerified,
  required Future<void> Function() completeVerifiedBootstrap,
  required Duration timeout,
}) async {
  try {
    await reload().timeout(timeout);
    if (!isVerified()) return false;
    await completeVerifiedBootstrap().timeout(timeout);
    return true;
  } on TimeoutException {
    throw const RiderOperationFailure(
      'Email verification took too long. Check your connection and try again.',
    );
  } catch (_) {
    throw const RiderOperationFailure(
      'Email verification could not be checked. Please try again.',
    );
  }
}

String riderOtpFailureMessage(String code) {
  return switch (code) {
    'invalid-verification-code' =>
      'That verification code is not correct. Try again.',
    'session-expired' =>
      'That verification code has expired. Request a new code.',
    'quota-exceeded' ||
    'too-many-requests' =>
      'Too many verification attempts. Wait a moment and try again.',
    'network-request-failed' =>
      'The connection dropped. Check your network and try again.',
    _ => 'Your verification code could not be confirmed. Please try again.',
  };
}

class RiderSignOutResult {
  const RiderSignOutResult({
    required this.remoteSignedOut,
    required this.localCleanupCompleted,
  });

  final bool remoteSignedOut;
  final bool localCleanupCompleted;
}

Future<RiderSignOutResult> runRiderSignOut({
  required Future<void> Function() signOut,
  required Future<void> Function() clearLocalSession,
  required Duration timeout,
}) async {
  var remoteSignedOut = false;
  var localCleanupCompleted = false;
  try {
    await signOut().timeout(timeout);
    remoteSignedOut = true;
  } catch (_) {
    // The caller keeps the authenticated route when remote sign-out fails.
  }
  try {
    await clearLocalSession().timeout(timeout);
    localCleanupCompleted = true;
  } catch (_) {
    // Return a deterministic result so the caller can surface safe recovery.
  }
  return RiderSignOutResult(
    remoteSignedOut: remoteSignedOut,
    localCleanupCompleted: localCleanupCompleted,
  );
}

Future<bool> runRiderAccountClosure({
  required Future<void> Function() reauthenticate,
  required Future<bool> Function() confirmClosure,
  required Future<void> Function() closeAccount,
  required Duration timeout,
}) async {
  try {
    await reauthenticate().timeout(timeout);
  } on TimeoutException {
    throw const RiderOperationFailure(
      'Sign-in confirmation took too long. Please try again.',
    );
  } catch (_) {
    throw const RiderOperationFailure(
      'Your identity could not be confirmed. Please sign in again.',
    );
  }

  if (!await confirmClosure()) return false;

  try {
    await closeAccount().timeout(timeout);
    return true;
  } on TimeoutException {
    throw const RiderOperationFailure(
      'Account closure took too long. Your account was not confirmed closed.',
    );
  } catch (_) {
    throw const RiderOperationFailure(
      'Your account could not be closed. Please try again.',
    );
  }
}
