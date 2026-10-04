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
