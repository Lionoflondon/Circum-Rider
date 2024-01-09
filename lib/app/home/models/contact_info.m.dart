import 'position_data.m.dart';

class ContactInfo {
  final String? fullname;
  final PositionData position;
  final String? phoneNumber;
  final String? moreInformation;
  final String? locality;
  final String? address;
  final String? subAddress;

  ContactInfo(
      {this.fullname,
      required this.position,
      this.phoneNumber,
      this.moreInformation,
      this.locality,
      this.address,
      this.subAddress});

  factory ContactInfo.fromJson(dynamic json) {
    return ContactInfo(
      fullname: json['fullname'],
      position: PositionData.fromJson(json['position']),
      phoneNumber: json['phone'],
      moreInformation: json['moreInformation'],
      locality: json['locality'],
      address: json['address'],
      subAddress: json['subAddress'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullname': fullname,
      'position': position,
      'phoneNumber': phoneNumber,
      'moreInformation': moreInformation,
      'locality': locality,
      'address': address,
      'subAddress': subAddress
    };
  }
}
