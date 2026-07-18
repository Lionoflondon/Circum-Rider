import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/earnings.m.dart';

class EarningsRepo {
  Future<EarningsModel> fetchEarnings({
    required String riderId,
  }) async {
    Dio dio = Dio();

    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        throw Exception("You must be signed in to fetch earnings");
      }

      var response = await dio.post(
        "https://us-central1-circum-2797c.cloudfunctions.net/calculateEarnings",
        data: {'riderId': riderId},
        options: Options(
          headers: {'Authorization': 'Bearer $idToken'},
          followRedirects: false,
          validateStatus: (status) {
            return status! < 500;
          },
        ),
      );

      return EarningsModel.fromJson(response.data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to fetch Rider earnings: $e');
      }
      throw Exception("Something went wrong");
    }
  }
}
