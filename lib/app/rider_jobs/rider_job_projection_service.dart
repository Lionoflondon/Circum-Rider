import 'package:cloud_functions/cloud_functions.dart';

class RiderJobProjectionSnapshot {
  const RiderJobProjectionSnapshot({
    required this.offers,
    required this.active,
    required this.completed,
  });

  final List<Map<String, dynamic>> offers;
  final List<Map<String, dynamic>> active;
  final List<Map<String, dynamic>> completed;

  Map<String, dynamic>? delivery(String deliveryId) {
    for (final job in [...active, ...completed]) {
      if ('${job['id'] ?? job['deliveryId']}' == deliveryId) return job;
    }
    return null;
  }
}

class RiderJobProjectionService {
  RiderJobProjectionService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<RiderJobProjectionSnapshot> load() async {
    final response =
        await _functions.httpsCallable('getAvailableRequests').call();
    final payload = Map<String, dynamic>.from(response.data as Map);
    return RiderJobProjectionSnapshot(
      offers: _records(payload['nearestRequests']),
      active: _records(payload['activeJobs']),
      completed: _records(payload['completedJobs']),
    );
  }

  static List<Map<String, dynamic>> _records(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}
