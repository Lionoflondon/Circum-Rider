class RiderAddressPresentation {
  final String displayName;
  final String addressLine1;
  final String addressLine2;
  final String locality;
  final String postcode;
  final String country;
  final double? latitude;
  final double? longitude;

  const RiderAddressPresentation({
    this.displayName = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.locality = '',
    this.postcode = '',
    this.country = '',
    this.latitude,
    this.longitude,
  });

  factory RiderAddressPresentation.fromValue(
    Object? value, {
    Object? fallback,
  }) {
    final map = _map(value);
    final nestedAddress = _map(map['address']);
    final position = _map(map['position'] ?? map['coordinate']);
    final geopoint = position['geopoint'] ?? position['geoPoint'];
    final coordinates = _coordinates(geopoint ?? position);
    final formatted = _scalar(map['formattedAddress']) ??
        _scalar(map['displayAddress']) ??
        _scalar(map['address']) ??
        _scalar(fallback);
    final structuredLine1 = _firstScalar([
      map['addressLine1'],
      map['line1'],
      map['streetAddress'],
      nestedAddress['addressLine1'],
      nestedAddress['line1'],
    ]);
    return RiderAddressPresentation(
      displayName: _firstScalar([
        map['placeName'],
        map['displayName'],
        map['venue'],
        map['buildingName'],
        nestedAddress['placeName'],
      ]),
      addressLine1:
          structuredLine1.isNotEmpty ? structuredLine1 : formatted ?? '',
      addressLine2: _firstScalar([
        map['addressLine2'],
        map['line2'],
        map['subAddress'],
        nestedAddress['addressLine2'],
      ]),
      locality: _firstScalar([
        map['locality'],
        map['city'],
        map['town'],
        nestedAddress['locality'],
        nestedAddress['city'],
      ]),
      postcode: _firstScalar([
        map['postcode'],
        map['postalCode'],
        nestedAddress['postcode'],
        nestedAddress['postalCode'],
        _postcodeFrom(formatted),
      ]),
      country: _firstScalar([
        map['country'],
        nestedAddress['country'],
      ]),
      latitude: coordinates.$1,
      longitude: coordinates.$2,
    );
  }

  String get area {
    if (postcode.isNotEmpty) return postcode;
    if (locality.isNotEmpty) return locality;
    if (displayName.isNotEmpty) return displayName;
    if (addressLine1.isNotEmpty) return addressLine1;
    return 'Location pending';
  }

  String get formatted {
    final parts = <String>[];
    void add(String value) {
      final text = value.trim();
      if (text.isNotEmpty && !parts.contains(text)) parts.add(text);
    }

    add(displayName);
    add(addressLine1);
    add(addressLine2);
    add(locality);
    if (!parts.join(' ').toUpperCase().contains(postcode.toUpperCase())) {
      add(postcode);
    }
    add(country);
    return parts.isEmpty ? 'Address pending' : parts.join(', ');
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

String? _scalar(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
}

String _firstScalar(Iterable<Object?> values) {
  for (final value in values) {
    final text = _scalar(value);
    if (text != null) return text;
  }
  return '';
}

String? _postcodeFrom(String? value) {
  if (value == null) return null;
  return RegExp(r'\b[A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2}\b', caseSensitive: false)
      .firstMatch(value)
      ?.group(0)
      ?.toUpperCase();
}

(double?, double?) _coordinates(Object? value) {
  if (value == null) return (null, null);
  if (value is Map) {
    final map = Map<Object?, Object?>.from(value);
    final nested = map['geoPointValue'];
    if (nested != null) return _coordinates(nested);
    return (
      _number(map['latitude'] ?? map['lat']),
      _number(map['longitude'] ?? map['lng'])
    );
  }
  try {
    final dynamic point = value;
    return (_number(point.latitude), _number(point.longitude));
  } catch (_) {
    return (null, null);
  }
}

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_scalar(value) ?? '');
}
