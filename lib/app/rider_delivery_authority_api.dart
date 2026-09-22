import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

const riderDeliveryAuthorityServiceUrl =
    'https://circum-rider-delivery-authority-516426305461.us-central1.run.app';

Future<Map<String, dynamic>> loadRiderOffersViaCloudRun({
  FirebaseAuth? auth,
  FirebaseAppCheck? appCheck,
  http.Client? client,
}) =>
    invokeRiderDeliveryAuthorityViaCloudRun(
      'getAvailableRequests',
      const {},
      auth: auth,
      appCheck: appCheck,
      client: client,
    );

Future<Map<String, dynamic>> completeDeliveryViaCloudRun(
  Map<String, dynamic> data, {
  FirebaseAuth? auth,
  FirebaseAppCheck? appCheck,
  http.Client? client,
}) =>
    invokeRiderDeliveryAuthorityViaCloudRun(
      'completeDelivery',
      data,
      auth: auth,
      appCheck: appCheck,
      client: client,
    );

Future<Map<String, dynamic>> invokeRiderDeliveryAuthorityViaCloudRun(
  String route,
  Map<String, dynamic> data, {
  FirebaseAuth? auth,
  FirebaseAppCheck? appCheck,
  http.Client? client,
}) async {
  if (route != 'completeDelivery' && route != 'getAvailableRequests') {
    throw ArgumentError.value(route, 'route', 'Unsupported Rider authority');
  }
  final user = (auth ?? FirebaseAuth.instance).currentUser;
  final idToken = await user?.getIdToken();
  if (idToken == null || idToken.isEmpty) {
    throw FirebaseFunctionsException(
      code: 'unauthenticated',
      message: 'Sign in to continue.',
    );
  }
  final appCheckToken =
      await (appCheck ?? FirebaseAppCheck.instance).getToken();
  if (appCheckToken == null || appCheckToken.isEmpty) {
    throw FirebaseFunctionsException(
      code: 'failed-precondition',
      message: 'Circum Rider security verification is required.',
    );
  }
  return invokeRiderDeliveryAuthorityWithTokens(
    route,
    data,
    idToken: idToken,
    appCheckToken: appCheckToken,
    client: client,
  );
}

Future<Map<String, dynamic>> invokeRiderDeliveryAuthorityWithTokens(
  String route,
  Map<String, dynamic> data, {
  required String idToken,
  required String appCheckToken,
  http.Client? client,
}) async {
  final ownsClient = client == null;
  final transport = client ?? http.Client();
  try {
    final response = await transport
        .post(
          Uri.parse('$riderDeliveryAuthorityServiceUrl/$route'),
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer $idToken',
            'x-firebase-appcheck': appCheckToken,
          },
          body: jsonEncode({'data': data}),
        )
        .timeout(const Duration(seconds: 30));
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final error = payload['error'] as Map?;
      throw FirebaseFunctionsException(
        code: _callableCode('${error?['status'] ?? 'INTERNAL'}'),
        message: '${error?['message'] ?? 'Rider delivery request failed.'}',
      );
    }
    final result = payload['result'];
    return result is Map ? Map<String, dynamic>.from(result) : const {};
  } on http.ClientException {
    throw FirebaseFunctionsException(
      code: 'unavailable',
      message: 'The connection dropped. Your progress is safe; try again.',
    );
  } finally {
    if (ownsClient) transport.close();
  }
}

String _callableCode(String status) => switch (status.toUpperCase()) {
      'INVALID_ARGUMENT' => 'invalid-argument',
      'UNAUTHENTICATED' => 'unauthenticated',
      'PERMISSION_DENIED' => 'permission-denied',
      'NOT_FOUND' => 'not-found',
      'FAILED_PRECONDITION' => 'failed-precondition',
      'RESOURCE_EXHAUSTED' => 'resource-exhausted',
      'UNAVAILABLE' => 'unavailable',
      'DEADLINE_EXCEEDED' => 'deadline-exceeded',
      _ => 'internal',
    };
