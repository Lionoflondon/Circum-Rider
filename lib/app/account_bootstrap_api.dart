import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

const riderAccountBootstrapServiceUrl =
    'https://circum-account-bootstrap-516426305461.us-central1.run.app';

Future<Map<String, dynamic>> updateRiderProfileViaCloudRun(
  Map<String, dynamic> data, {
  FirebaseAuth? auth,
  FirebaseAppCheck? appCheck,
  http.Client? client,
}) async {
  return _callRiderAccountViaCloudRun(
    'updateRiderProfile',
    data,
    auth: auth,
    appCheck: appCheck,
    client: client,
  );
}

Future<Map<String, dynamic>> submitRiderApplicationViaCloudRun(
  Map<String, dynamic> data, {
  FirebaseAuth? auth,
  FirebaseAppCheck? appCheck,
  http.Client? client,
}) async {
  return _callRiderAccountViaCloudRun(
    'submitRiderApplication',
    data,
    auth: auth,
    appCheck: appCheck,
    client: client,
  );
}

Future<Map<String, dynamic>> _callRiderAccountViaCloudRun(
  String operation,
  Map<String, dynamic> data, {
  FirebaseAuth? auth,
  FirebaseAppCheck? appCheck,
  http.Client? client,
}) async {
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
      message: 'Circum security verification is required.',
    );
  }
  return _invokeRiderAccountViaCloudRun(
    operation,
    data,
    idToken: idToken,
    appCheckToken: appCheckToken,
    client: client,
  );
}

Future<Map<String, dynamic>> invokeRiderProfileUpdateViaCloudRun(
  Map<String, dynamic> data, {
  required String idToken,
  required String appCheckToken,
  http.Client? client,
}) async {
  return _invokeRiderAccountViaCloudRun(
    'updateRiderProfile',
    data,
    idToken: idToken,
    appCheckToken: appCheckToken,
    client: client,
  );
}

Future<Map<String, dynamic>> invokeSubmitRiderApplicationViaCloudRun(
  Map<String, dynamic> data, {
  required String idToken,
  required String appCheckToken,
  http.Client? client,
}) async {
  return _invokeRiderAccountViaCloudRun(
    'submitRiderApplication',
    data,
    idToken: idToken,
    appCheckToken: appCheckToken,
    client: client,
  );
}

Future<Map<String, dynamic>> _invokeRiderAccountViaCloudRun(
  String operation,
  Map<String, dynamic> data, {
  required String idToken,
  required String appCheckToken,
  http.Client? client,
}) async {
  final ownsClient = client == null;
  final transport = client ?? http.Client();
  try {
    final response = await transport.post(
      Uri.parse('$riderAccountBootstrapServiceUrl/$operation'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $idToken',
        'x-firebase-appcheck': appCheckToken,
      },
      body: jsonEncode({'data': data}),
    );
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final error = payload['error'] as Map?;
      throw FirebaseFunctionsException(
        code: _callableCode('${error?['status'] ?? 'INTERNAL'}'),
        message: '${error?['message'] ?? 'Account request failed.'}',
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
      'FAILED_PRECONDITION' => 'failed-precondition',
      'RESOURCE_EXHAUSTED' => 'resource-exhausted',
      'UNAVAILABLE' => 'unavailable',
      'DEADLINE_EXCEEDED' => 'deadline-exceeded',
      _ => 'internal',
    };
