/// Select only the legacy canonical document owned by this authenticated Rider.
String? riderVehicleDocumentStatus(
  Iterable<Map<String, dynamic>> documents, {
  required String riderId,
}) {
  for (final document in documents) {
    if (document['riderId'] != riderId ||
        document['documentId'] != '${riderId}_vehicle_registration') continue;
    final status =
        '${document['status'] ?? document['verificationStatus'] ?? ''}'.trim();
    return status.isEmpty ? null : status;
  }
  return null;
}
