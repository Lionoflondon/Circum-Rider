import 'package:dio/dio.dart';

class HomeRepo {
  Future<String> endTrip({
    required String riderId,
    required String requestId,
    required String riderName,
  }) async {
    Dio dio = Dio();

    try {
      var response = await dio.post(
        "https://us-central1-circum-2797c.cloudfunctions.net/endTrip",
        data: {
          'riderId': riderId,
          'requestId': requestId,
          'riderName': riderName
        },
        options: Options(
          followRedirects: false,
          validateStatus: (status) {
            return status! < 500;
          },
        ),
      );
      // print(response.data);

      return response.data["historyId"];
    } catch (e) {
      print(e);
      throw Exception("Something went wrong");
    }
  }
}
