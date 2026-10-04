import 'dart:convert';

String? riderOfferId(Map<String, dynamic> data) {
  String? read(Map<dynamic, dynamic> values) {
    for (final key in ['deliveryId', 'requestId', 'bookingId']) {
      final id = '${values[key] ?? ''}'.trim();
      if (id.isNotEmpty && !id.contains('/')) return id;
    }
    return null;
  }

  final direct = read(data);
  if (direct != null) return direct;
  try {
    final decoded =
        data['data'] is String ? jsonDecode(data['data']) : data['data'];
    return decoded is Map ? read(decoded) : null;
  } catch (_) {
    return null;
  }
}

/// Keep only routing identifiers in the encrypted restart inbox.
Map<String, dynamic> riderPendingPushData(Map<String, dynamic> data) {
  const keys = {
    'type',
    'notificationType',
    'route',
    'notificationId',
    'deliveryId',
    'requestId',
    'bookingId',
    'chatId',
    'payoutRequestId',
    'withdrawalId',
    'applicationId',
    'entityId'
  };
  Map<String, dynamic> filter(Map values) => {
        for (final key in keys)
          if (values[key] is String && (values[key] as String).length <= 512)
            key: values[key],
      };
  final result = filter(data);
  try {
    final raw =
        data['data'] is String ? jsonDecode(data['data']) : data['data'];
    if (raw is Map) result['data'] = jsonEncode(filter(raw));
  } catch (_) {
    /* Malformed legacy payload falls back to notification centre. */
  }
  return result;
}
