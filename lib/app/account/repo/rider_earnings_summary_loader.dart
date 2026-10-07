import 'dart:async';

/// Attach an error observer before the screen can return early or be disposed.
/// Consumers still receive the original failure; no balance is fabricated.
Future<Map<String, dynamic>> loadRiderEarningsSummary({
  required String? Function() currentUid,
  required Future<dynamic> Function() load,
  Duration timeout = const Duration(seconds: 25),
}) {
  final future = () async {
    final initiatingUid = currentUid();
    if (initiatingUid == null) throw StateError('Sign in to view earnings.');
    final data = await load().timeout(timeout);
    if (currentUid() != initiatingUid) {
      throw StateError('Account changed. Refresh earnings.');
    }
    return Map<String, dynamic>.from(data as Map);
  }();
  future.ignore();
  return future;
}
