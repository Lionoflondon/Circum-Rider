import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RiderProductionPaymentApi {
  RiderProductionPaymentApi._();

  static final Dio _dio = Dio();

  static const _connectBase =
      'https://circum-rider-connect-accounts-j2b7cicfwq-uc.a.run.app';
  static const _payoutBase =
      'https://circum-rider-payouts-j2b7cicfwq-uc.a.run.app';

  static Future<Map<String, dynamic>> connect(String route,
          [Map<String, dynamic> payload = const {}]) =>
      _call(_connectBase, route, payload);

  static Future<Map<String, dynamic>> payout(String route,
          [Map<String, dynamic> payload = const {}]) =>
      _call(_payoutBase, route, payload);

  static Future<Map<String, dynamic>> _call(
    String base,
    String route,
    Map<String, dynamic> payload,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('signed_out');
    final token = await user.getIdToken();
    final response = await _dio
        .post<Map<String, dynamic>>(
          '$base/$route',
          data: <String, dynamic>{'data': payload},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        )
        .timeout(const Duration(seconds: 25));
    final body = response.data ?? const <String, dynamic>{};
    final result = body['result'] ?? body['data'];
    return result is Map
        ? Map<String, dynamic>.from(result)
        : const <String, dynamic>{};
  }
}
