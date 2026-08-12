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
    final source = json is Map ? json : const <String, dynamic>{};
    String? scalar(dynamic value) {
      if (value == null || value is Map || value is Iterable) return null;
      final text = '$value'.trim();
      return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
    }

    return ContactInfo(
      fullname: scalar(source['fullname'] ?? source['name']),
      position: PositionData.fromJson(source['position']),
      phoneNumber: scalar(source['phone'] ?? source['phoneNumber']),
      moreInformation: scalar(source['moreInformation']),
      locality: scalar(source['locality'] ?? source['city']),
      address: scalar(source['address'] ?? source['formattedAddress']),
      subAddress: scalar(source['subAddress'] ?? source['displayAddress']),
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
