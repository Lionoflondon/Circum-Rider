import 'package:cloud_functions/cloud_functions.dart';

import 'rider_offer_card.dart';

/// Every refresh is authorized on the backend before any offer data is returned.
class RiderOfferFeed {
  RiderOfferFeed({Future<Map<String, dynamic>> Function()? load})
      : _load = load ?? _loadFromBackend;

  final Future<Map<String, dynamic>> Function() _load;

  static Future<Map<String, dynamic>> _loadFromBackend() async {
    final response = await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('getAvailableRequests')
        .call(<String, dynamic>{}).timeout(const Duration(seconds: 15));
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<RiderJobOffer>> refresh({required String riderId}) async {
    final response = await _load();
    if (response['riderId'] != riderId || response['eligible'] != true) {
      return const [];
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = response['nearestRequests'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) =>
            row['projectionVersion'] == 2 &&
            row['offerExpiresAt'] is num &&
            (row['offerExpiresAt'] as num) > now)
        .map((row) => RiderJobOffer.fromFirestore(
            docId: row['deliveryId'] as String, data: row))
        .toList(growable: false);
  }

  Stream<List<RiderJobOffer>> watch({required String riderId}) async* {
    while (true) {
      try {
        yield await refresh(riderId: riderId);
      } catch (error, stack) {
        // A failed refresh must replace the previous offer list, never retain it.
        yield const [];
        yield* Stream<List<RiderJobOffer>>.error(error, stack);
      }
      await Future<void>.delayed(const Duration(seconds: 10));
    }
  }
}
