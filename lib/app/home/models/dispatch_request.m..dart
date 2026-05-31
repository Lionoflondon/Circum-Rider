import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../../helper/format_date.dart';
import 'contact_info.m.dart';

class DispatchRequest extends Equatable {
  final ContactInfo pickupData;
  final ContactInfo dropoffData;
  final String requestId;
  final String code;
  final double price;
  final String currency;
  final Timestamp? createdAt;
  final String? riderName;
  final double? userRating;
  final double? riderRating;
  const DispatchRequest(
      {required this.pickupData,
      required this.dropoffData,
      required this.requestId,
      required this.code,
      required this.price,
      required this.currency,
      this.createdAt,
      this.riderName,
      this.userRating,
      this.riderRating});

  @override
  List<Object> get props => [
        {pickupData},
        {dropoffData},
        {requestId},
        {code},
        {price},
        {createdAt},
        {riderName},
        {userRating},
        {riderRating},
      ];

  static DispatchRequest fromJson(dynamic json) {
    final createdAtValue = json['createdAt'];
    Timestamp? createdAt;

    if (createdAtValue is Timestamp) {
      createdAt = createdAtValue;
    } else if (createdAtValue is Map &&
        createdAtValue['_seconds'] != null &&
        createdAtValue['_nanoseconds'] != null) {
      createdAt = Timestamp(
        createdAtValue['_seconds'],
        createdAtValue['_nanoseconds'],
      );
    }

    return DispatchRequest(
      pickupData: ContactInfo.fromJson(json['pickupDetails']),
      dropoffData: ContactInfo.fromJson(json['dropoffDetails']),
      requestId: json['requestId'] ?? '',
      code: json['code'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] ?? 'GBP',
      createdAt: createdAt,
      riderName: json['riderName'],
      userRating: (json['userRating'] as num?)?.toDouble(),
      riderRating: (json['riderRating'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() => '''DispatchRequests { 
      pickupData: $pickupData, 
      dropoffData: $dropoffData,
      price: $price
      }
''';
}
