import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;

/// Require an explicit result before acknowledging an account or delivery write.
Map<String, dynamic> decodeRiderMapResponse(http.Response response) {
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
  return result;
}
