bool isAuthoritativeRiderPresenceOnline(Map<String, dynamic> presence) {
  if (presence['isOnline'] != true) return false;

  final availability =
      '${presence['availabilityStatus'] ?? ''}'.trim().toLowerCase();
  if (availability == 'offline') return false;

  final presenceState =
      '${presence['presenceState'] ?? ''}'.trim().toLowerCase();
  if (presenceState.isNotEmpty && presenceState != 'fresh') return false;

  final connection =
      '${presence['connectionStatus'] ?? ''}'.trim().toLowerCase();
  if (const {'offline', 'stale', 'disconnected'}.contains(connection)) {
    return false;
  }

  return true;
}
