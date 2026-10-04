import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

const riderCallableOwners = <String, String>{
  'updateRiderPushToken':
      'https://circum-rider-operations-516426305461.us-central1.run.app',
  'confirmRiderIrisAssessment':
      'https://circum-rider-operations-516426305461.us-central1.run.app',
  'ensurePublicRiderId':
      'https://circum-rider-operations-516426305461.us-central1.run.app',
  'ensureRiderRothWallet':
      'https://circum-rider-operations-516426305461.us-central1.run.app',
  'getGooglePlayReviewFixture':
      'https://circum-rider-operations-516426305461.us-central1.run.app',
  'markConversationRead':
      'https://circum-rider-operations-516426305461.us-central1.run.app',
  'markRiderNoShow':
      'https://circum-rider-operations-516426305461.us-central1.run.app',
  'repairRiderRatingFeedback':
      'https://circum-rider-operations-516426305461.us-central1.run.app',
  'reportLoadDiscrepancy':
      'https://circum-rider-operations-516426305461.us-central1.run.app',
  'reportRating':
      'https://circum-rider-operations-516426305461.us-central1.run.app',
  'reportWaitingContext':
      'https://circum-rider-operations-516426305461.us-central1.run.app',
  'requestRiderCancellation':
      'https://circum-rider-operations-516426305461.us-central1.run.app',
  'sendCircumMessage':
      'https://circum-rider-operations-516426305461.us-central1.run.app',
  'setConversationTyping':
      'https://circum-rider-operations-516426305461.us-central1.run.app',
  'setGooglePlayReviewPresence':
      'https://circum-rider-operations-516426305461.us-central1.run.app',
  'submitRiderDocument':
      'https://circum-rider-operations-516426305461.us-central1.run.app',
  'updateRiderApplicationSection':
      'https://circum-rider-operations-516426305461.us-central1.run.app',
  'updateRiderNotificationState':
      'https://circum-rider-operations-516426305461.us-central1.run.app',
  'acceptRideRequests':
      'https://circum-rider-delivery-authority-j2b7cicfwq-uc.a.run.app',
  'recordRiderArrival':
      'https://circum-rider-delivery-authority-j2b7cicfwq-uc.a.run.app',
  'getRiderEarningsSummary':
      'https://circum-rider-payouts-j2b7cicfwq-uc.a.run.app',
  'requestRiderWithdrawal':
      'https://circum-rider-payouts-j2b7cicfwq-uc.a.run.app',
  'cancelRiderWithdrawal':
      'https://circum-rider-payouts-j2b7cicfwq-uc.a.run.app',
  'riderPayoutReadiness':
      'https://circum-rider-payouts-j2b7cicfwq-uc.a.run.app',
  'syncStripeConnectStatus':
      'https://circum-rider-connect-accounts-j2b7cicfwq-uc.a.run.app',
  'createStripeAccountManagementLink':
      'https://circum-rider-connect-accounts-j2b7cicfwq-uc.a.run.app',
  'createStripeConnectAccountForRider':
      'https://circum-rider-connect-accounts-j2b7cicfwq-uc.a.run.app',
  'createStripeOnboardingLink':
      'https://circum-rider-connect-accounts-j2b7cicfwq-uc.a.run.app',
  'refreshStripeOnboardingLink':
      'https://circum-rider-connect-accounts-j2b7cicfwq-uc.a.run.app',
  'verifyRiderAccountAccess':
      'https://circum-account-bootstrap-j2b7cicfwq-uc.a.run.app',
  'closeCircumAccount':
      'https://circum-account-bootstrap-j2b7cicfwq-uc.a.run.app',
};

class RiderCallableResult<T> {
  const RiderCallableResult(this.data);
  final T data;
}

extension RiderCallableTransport on FirebaseFunctions {
  RiderCallable riderCallable(String name) => RiderCallable(name);
}

class RiderCallable {
  RiderCallable(this.name);
  final String name;
  Future<RiderCallableResult<T>> call<T>([
    Map<String, dynamic> data = const {},
  ]) async {
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    final appCheckToken = await FirebaseAppCheck.instance.getToken();
    return RiderCallableResult<T>(
      (await invokeRiderCallable(
        name,
        data,
        idToken: idToken,
        appCheckToken: appCheckToken,
      )) as T,
    );
  }
}

Future<dynamic> invokeRiderCallable(
  String name,
  Map<String, dynamic> data, {
  required String? idToken,
  required String? appCheckToken,
  http.Client? client,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final base = riderCallableOwners[name];
  if (base == null)
    throw ArgumentError.value(name, 'name', 'Unsupported Rider operation');
  if (idToken == null || idToken.isEmpty)
    throw FirebaseFunctionsException(
      code: 'unauthenticated',
      message: 'Sign in to continue.',
    );
  if (appCheckToken == null || appCheckToken.isEmpty)
    throw FirebaseFunctionsException(
      code: 'failed-precondition',
      message: 'Circum security verification is required.',
    );
  final transport = client ?? http.Client();
  try {
    final response = await transport
        .post(
          Uri.parse('$base/$name'),
          headers: {
            'Authorization': 'Bearer $idToken',
            'X-Firebase-AppCheck': appCheckToken,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'data': data}),
        )
        .timeout(timeout);
    dynamic payload;
    try {
      payload = jsonDecode(response.body);
    } on FormatException {
      throw FirebaseFunctionsException(
        code: response.statusCode >= 500 ? 'unavailable' : 'internal',
        message:
            'The service could not confirm this request. Refresh its status before retrying.',
      );
    }
    if (payload is! Map)
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'Invalid service response.',
      );
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload.containsKey('error')) {
      final error = payload['error'];
      throw FirebaseFunctionsException(
        code: (error is Map
                ? '${error['status'] ?? error['code'] ?? 'INTERNAL'}'
                : response.statusCode >= 500
                    ? 'UNAVAILABLE'
                    : 'INTERNAL')
            .toLowerCase()
            .replaceAll('_', '-'),
        message: error is Map
            ? '${error['message'] ?? 'Request failed.'}'
            : 'Request failed.',
        details: error is Map ? error['details'] : null,
      );
    }
    if (payload.containsKey('result')) return payload['result'];
    if (payload.containsKey('data')) return payload['data'];
    throw FirebaseFunctionsException(
      code: 'internal',
      message: 'The service did not confirm this request.',
    );
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
    if (client == null) transport.close();
  }
}
