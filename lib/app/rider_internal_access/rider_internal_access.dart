import 'package:firebase_auth/firebase_auth.dart';

abstract final class RiderInternalAccess {
  static Future<bool> enabled({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final token = await user.getIdTokenResult(forceRefresh);
    return token.claims?['founderRider'] == true;
  }
}
