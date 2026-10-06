import 'package:circum_rider/app/authentication/rider_vehicle_document_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing documents leave verification pending', () {
    expect(riderVehicleDocumentStatus([], riderId: 'qa'), isNull);
  });
  test(
      'other owners and document categories cannot establish vehicle verification',
      () {
    expect(
        riderVehicleDocumentStatus([
          {
            'riderId': 'other',
            'documentId': 'qa_vehicle_registration',
            'status': 'verified'
          },
          {'riderId': 'qa', 'documentId': 'qa_insurance', 'status': 'verified'},
        ], riderId: 'qa'),
        isNull);
  });
  test('the own canonical vehicle document provides its authoritative status',
      () {
    expect(
        riderVehicleDocumentStatus([
          {
            'riderId': 'qa',
            'documentId': 'qa_vehicle_registration',
            'verificationStatus': 'pending_review'
          },
        ], riderId: 'qa'),
        'pending_review');
  });
}
