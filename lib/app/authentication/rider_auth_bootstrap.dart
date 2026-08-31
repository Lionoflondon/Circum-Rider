import 'dart:async';

enum RiderBootstrapStage { displayName, profile, rothWallet }

bool riderOnboardingNeedsProfileStart(String? status) {
  final normalized = status?.trim().toLowerCase() ?? '';
  return normalized.isEmpty ||
      normalized == 'not_started' ||
      normalized == 'account_created';
}

class RiderBootstrapException implements Exception {
  const RiderBootstrapException(this.stage, this.cause);

  final RiderBootstrapStage stage;
  final Object cause;
}

Future<void> runRiderAuthBootstrap({
  required Future<void> Function() updateDisplayName,
  required Future<void> Function() initializeProfile,
  required Future<void> Function() initializeRothWallet,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);

  Future<void> run(
    RiderBootstrapStage stage,
    Future<void> Function() operation,
  ) async {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      throw RiderBootstrapException(stage, TimeoutException(stage.name));
    }
    try {
      await operation().timeout(remaining);
    } catch (error) {
      throw RiderBootstrapException(stage, error);
    }
  }

  await run(RiderBootstrapStage.displayName, updateDisplayName);
  await run(RiderBootstrapStage.profile, initializeProfile);
  await run(RiderBootstrapStage.rothWallet, initializeRothWallet);
}
