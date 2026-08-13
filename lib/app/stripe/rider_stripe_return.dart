enum RiderStripeReturnAction { completed, refresh }

class RiderStripeReturnIntent {
  const RiderStripeReturnIntent({
    required this.action,
    required this.canonicalPath,
    this.returnedRiderId,
  });

  static const returnPath = '/rider/stripe/return';
  static const refreshPath = '/rider/stripe/refresh';
  static const canonicalHosts = {
    'circum-rider-2797c.web.app',
    'circum-rider-2797c.firebaseapp.com',
  };

  final RiderStripeReturnAction action;
  final String canonicalPath;

  /// Retained only as return-flow context. Backend calls always derive the
  /// Rider identity from the restored Firebase Auth session.
  final String? returnedRiderId;

  bool get isRefresh => action == RiderStripeReturnAction.refresh;

  static RiderStripeReturnIntent? fromUri(Uri uri) {
    final host = uri.host.trim().toLowerCase();
    final localDevelopment = host == 'localhost' || host == '127.0.0.1';
    if (host.isNotEmpty &&
        !canonicalHosts.contains(host) &&
        !localDevelopment) {
      return null;
    }
    final normalizedPath = _normalizedPath(uri.path);
    final action = switch (normalizedPath) {
      returnPath => RiderStripeReturnAction.completed,
      refreshPath => RiderStripeReturnAction.refresh,
      _ => null,
    };
    if (action == null) return null;

    final riderId = uri.queryParameters['riderId']?.trim();
    return RiderStripeReturnIntent(
      action: action,
      canonicalPath: normalizedPath,
      returnedRiderId: riderId == null || riderId.isEmpty ? null : riderId,
    );
  }

  static String _normalizedPath(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '/') return '/';
    final withLeadingSlash = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return withLeadingSlash.endsWith('/')
        ? withLeadingSlash.substring(0, withLeadingSlash.length - 1)
        : withLeadingSlash;
  }
}
