const riderVehicleChoices = {
  'motorbike': 'Motorbike',
  'car': 'Car',
  'van': 'Van'
};

String? riderVehicleValue(Object? value) {
  final token = '${value ?? ''}'.trim().toLowerCase().replaceAll(' ', '_');
  final canonical = const {
        'motorcycle': 'motorbike',
        'motor_bike': 'motorbike',
        'motor_cycle': 'motorbike'
      }[token] ??
      token;
  return riderVehicleChoices.containsKey(canonical) ? canonical : null;
}

String riderDocumentType(Object? value) {
  final token = '${value ?? ''}'
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '_');
  return const {
        'passport': 'identity',
        'national_identity_card': 'identity',
        'identity_selfie': 'identity',
        'drivers_license': 'driving_licence',
        'vehicle_registration': 'registration_v5c',
        'v5c': 'registration_v5c',
        'share_code': 'right_to_work'
      }[token] ??
      token;
}

String riderDocumentReviewState(Map<String, dynamic> document) =>
    '${document['status'] ?? document['verificationStatus'] ?? ''}'
        .trim()
        .toLowerCase();

List<Map<String, dynamic>> latestRiderDocuments(
    List<Map<String, dynamic>> documents) {
  final latest = <String, Map<String, dynamic>>{};
  int time(Map<String, dynamic> d) {
    final value = d['uploadedAt'] ?? d['createdAt'];
    if (value is DateTime) return value.millisecondsSinceEpoch;
    try {
      return (value as dynamic).millisecondsSinceEpoch as int;
    } catch (_) {
      return 0;
    }
  }

  for (final doc in documents) {
    final key =
        riderDocumentType(doc['type'] ?? doc['documentType'] ?? doc['idType']);
    if (!latest.containsKey(key) || time(doc) >= time(latest[key]!)) {
      latest[key] = doc;
    }
  }
  return latest.values.toList();
}

bool riderDocumentSubmitted(Map<String, dynamic> document) => const {
      'pending',
      'uploaded',
      'submitted',
      'under_review',
      'approved',
      'accepted',
      'verified',
    }.contains(riderDocumentReviewState(document));

String? riderUploadError(String name, int size) {
  if (!const {'pdf', 'jpg', 'jpeg', 'png', 'webp'}
      .contains(name.split('.').last.toLowerCase())) {
    return 'Choose a JPG, JPEG, PNG, WEBP or PDF document.';
  }
  if (size <= 0) return 'The selected file is empty. Choose another file.';
  if (size > 8 * 1024 * 1024) return 'Documents must be 8 MiB or smaller.';
  return null;
}

bool riderVehicleApproved(Map<String, dynamic> record) {
  bool approved(Object? value) =>
      const {'true', 'approved'}.contains('${value ?? ''}'.toLowerCase());
  final vehicle =
      record['vehicle'] is Map ? record['vehicle'] as Map : const {};
  return approved(record['vehicleApproved']) ||
      approved(record['vehicleVerified']) ||
      record['vehicleStatus'] == 'approved' ||
      vehicle['status'] == 'approved' ||
      approved(vehicle['approved']);
}
