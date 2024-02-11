import 'package:dio/dio.dart';

import '../models/earnings.m.dart';

class EarningsRepo {
  Future<EarningsModel> fetchEarnings({
    required String riderId,
  }) async {
    Dio dio = Dio();

    try {
      var response = await dio.post(
        "https://us-central1-circum-2797c.cloudfunctions.net/calculateEarnings",
        data: {'riderId': riderId},
        options: Options(
          followRedirects: false,
          validateStatus: (status) {
            return status! < 500;
          },
        ),
      );

      return EarningsModel.fromJson(response.data);
    } catch (e) {
      print(e);
      throw Exception("Something went wrong");
    }
  }
}
