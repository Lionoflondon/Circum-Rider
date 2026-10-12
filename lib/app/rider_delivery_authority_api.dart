import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'rider_map_response.dart';

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

bool isQaPublicDeliveryId(String deliveryId) =>
    deliveryId.startsWith('qa_public_');

Future<Map<String, dynamic>> invokeRiderDeliveryAuthorityViaCloudRun(
  String route,
  Map<String, dynamic> data, {
  FirebaseAuth? auth,
  FirebaseAppCheck? appCheck,
  http.Client? client,
}) async {
  if (route != 'completeDelivery' &&
      route != 'acceptRideRequests' &&
      route != 'recordRiderArrival' &&
      route != 'getAvailableRequests' &&
      route != 'updateDeliveryTrackingStatus' &&
      route != 'updateDeliveryLiveLocation' &&
      route != 'goOnline' &&
      route != 'goOffline' &&
      route != 'updateRiderPresence') {
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
    return decodeRiderMapResponse(response, operation: route);
  } on TimeoutException {
    throw FirebaseFunctionsException(
      code: 'deadline-exceeded',
      message:
          'Confirmation took too long. Refresh its status before retrying.',
    );
  } on http.ClientException {
    throw FirebaseFunctionsException(
      code: 'unavailable',
      message: 'Connection interrupted. Refresh its status before retrying.',
    );
  } finally {
    if (ownsClient) transport.close();
  }
}
