import 'package:cloud_functions/cloud_functions.dart';

class RiderReviewFixtureService {
  RiderReviewFixtureService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> getOwnFixture() async {
    final result =
        await _functions.httpsCallable('getGooglePlayReviewFixture').call();
    final data = result.data;
    if (data is! Map) throw StateError('Review fixture is unavailable.');
    return Map<String, dynamic>.from(data);
  }

  Future<String> setPresence({
    required String fixtureId,
    required bool online,
  }) async {
    final result = await _functions
        .httpsCallable('setGooglePlayReviewPresence')
        .call(<String, dynamic>{
      'fixtureId': fixtureId,
      'presence': online ? 'online' : 'offline',
    });
    final data = result.data;
    if (data is! Map || data['reviewPresence'] is! String) {
      throw StateError('Review presence is unavailable.');
    }
    return '${data['reviewPresence']}';
  }
}
