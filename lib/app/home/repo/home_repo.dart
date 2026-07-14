import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeRepo {
  Future<String> endTrip({
    required String riderId,
    required String requestId,
    required String riderName,
  }) async {
    Dio dio = Dio();

    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        throw Exception("You must be signed in to complete this trip");
      }

      var response = await dio.post(
        "https://us-central1-circum-2797c.cloudfunctions.net/endTrip",
        data: {
          'riderId': riderId,
          'requestId': requestId,
          'riderName': riderName
        },
        options: Options(
          headers: {'Authorization': 'Bearer $idToken'},
          followRedirects: false,
          validateStatus: (status) {
            return status! < 500;
          },
        ),
      );
      if (response.statusCode == 409) {
        return response.data["historyId"] ?? "";
      }
      if ((response.statusCode ?? 0) >= 400) {
        throw Exception(response.data["msg"] ?? "Something went wrong");
      }

      return response.data["historyId"];
    } catch (_) {
      throw Exception("Something went wrong");
    }
  }
}
