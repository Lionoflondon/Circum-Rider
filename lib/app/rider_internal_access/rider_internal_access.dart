import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

abstract final class RiderInternalAccess {
  static Future<bool> enabled({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final token = await user.getIdTokenResult(forceRefresh);
    if (token.claims?['founderRider'] == true) return true;
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('getFounderRiderAccess')
          .call();
      return result.data is Map && result.data['operational'] == true;
    } catch (_) {
      return false;
    }
  }
}
