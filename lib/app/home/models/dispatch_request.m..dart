import 'package:equatable/equatable.dart';

import 'contact_info.m.dart';

class DispatchRequest extends Equatable {
  final ContactInfo pickupData;
  final ContactInfo dropoffData;
  final String requestId;
  final String code;
  const DispatchRequest(
      {required this.pickupData,
      required this.dropoffData,
      required this.requestId,
      required this.code});

  @override
  List<Object> get props => [
        {pickupData},
        {dropoffData},
        {requestId},
        {code}
      ];

  static DispatchRequest fromJson(dynamic json) {
    return DispatchRequest(
      pickupData: ContactInfo.fromJson(json['pickupDetails']),
      dropoffData: ContactInfo.fromJson(json['dropoffDetails']),
      requestId: json['requestId'],
      code: json['code'],
    );
  }

  @override
  String toString() => '''DispatchRequests { 
      pickupData: $pickupData, 
      dropoffData: $dropoffData
      }
''';
}
