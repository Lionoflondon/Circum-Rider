import '../rider_callable_api.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RiderProductionPaymentApi {
  RiderProductionPaymentApi._();
  static Future<Map<String, dynamic>> connect(
    String route, [
    Map<String, dynamic> payload = const {},
  ]) =>
      _call(route, payload);
  static Future<Map<String, dynamic>> payout(
    String route, [
    Map<String, dynamic> payload = const {},
  ]) =>
      _call(route, payload);
  static Future<Map<String, dynamic>> _call(
    String route,
    Map<String, dynamic> payload,
  ) async {
    final result = await invokeRiderCallable(
      route,
      payload,
      idToken: await FirebaseAuth.instance.currentUser?.getIdToken(),
      appCheckToken: await FirebaseAppCheck.instance.getToken(),
    );
    if (result is! Map) throw StateError('Invalid Rider response');
    return Map<String, dynamic>.from(result);
  }
}
