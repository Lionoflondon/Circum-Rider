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
}
