import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;

/// Require an explicit result before acknowledging an account or delivery write.
Map<String, dynamic> decodeRiderMapResponse(http.Response response,
    {required String operation}) {
  final fallbackCode = switch (response.statusCode) {
    401 => 'unauthenticated',
    403 => 'permission-denied',
    429 => 'resource-exhausted',
    >= 500 => 'unavailable',
    _ => 'internal',
  };
  const fallbackMessage =
      'The service could not confirm this request. Refresh its status before retrying.';
  Object? decoded;
  try {
    decoded = jsonDecode(response.body);
  } on FormatException {
    throw FirebaseFunctionsException(
        code: fallbackCode, message: fallbackMessage);
  }
  if (decoded is! Map<String, dynamic>) {
    throw FirebaseFunctionsException(
        code: fallbackCode, message: fallbackMessage);
  }
  if (response.statusCode != 200 || decoded.containsKey('error')) {
    final error = decoded['error'];
    throw FirebaseFunctionsException(
      code: error is Map && error['status'] is String
          ? (error['status'] as String).toLowerCase().replaceAll('_', '-')
          : fallbackCode,
      message: error is Map && error['message'] is String
          ? error['message'] as String
          : fallbackMessage,
      details: error is Map ? error['details'] : null,
    );
  }
  final result = decoded['result'];
  if (result is! Map<String, dynamic>) {
    throw FirebaseFunctionsException(
        code: 'internal', message: fallbackMessage);
  }
  final confirmed = switch (operation) {
    'updateRiderProfile' => result['ok'] == true,
    'advanceRiderOnboarding' => result['ok'] == true &&
        const {
          'profile_started',
          'phone_verified',
          'email_verified',
          'profile_complete'
        }.contains(result['onboardingStatus']),
    'submitRiderApplication' => result['applicationId'] is String &&
        (result['applicationId'] as String).trim().isNotEmpty &&
        const {
          'submitted',
          'resubmitted',
          'under_review',
          'approved',
          'suspended',
          'archived'
        }.contains(result['status']),
    'sendCircumVerificationEmail' => result['ok'] == true &&
        (result['queued'] == true || result['alreadyVerified'] == true),
    'completeDelivery' =>
      const {'delivered', 'completed'}.contains(result['status']),
    'acceptRideRequests' => result['status'] == 'accepted',
    'updateDeliveryTrackingStatus' => const {
        'navigating_to_pickup',
        'arrived_at_pickup',
        'pickup_verified',
        'collected',
        'navigating_to_dropoff',
        'arrived_at_dropoff',
        'delivered',
        'completed',
        'issue_reported',
        'cancelled',
        'settlement_pending',
      }.contains(result['status']),
    'recordRiderArrival' => result['success'] is bool &&
        result['decision'] is Map &&
        (result['success'] == false ||
            const {'arrived_at_pickup', 'arrived_at_dropoff'}
                .contains((result['decision'] as Map)['state'])),
    'updateDeliveryLiveLocation' => result['success'] == true,
    'goOnline' => result['success'] == true &&
        result['dispatchEligible'] is bool &&
        result['presence'] is Map,
    'goOffline' ||
    'updateRiderPresence' =>
      result['success'] == true && result['presence'] is Map,
    'getAvailableRequests' => result['eligible'] is bool &&
        result['nearestRequests'] is List &&
        (result['nearestRequests'] as List).every((offer) => offer is Map),
    _ => false,
  };
  if (!confirmed) {
    throw FirebaseFunctionsException(
        code: 'internal', message: fallbackMessage);
  }
  return result;
}
