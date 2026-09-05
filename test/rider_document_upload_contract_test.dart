import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final upload =
      File('lib/app/verification/view/upload_id.dart').readAsStringSync();
  final auth =
      File('lib/app/authentication/bloc/auth_bloc.dart').readAsStringSync();
  final centre =
      File('lib/app/verification/view/verification.dart').readAsStringSync();
  final applicationCentre =
      File('lib/app/onboarding/rider_application_centre.dart')
          .readAsStringSync();

  test('document-first input and bounded backend submission are preserved', () {
    expect(upload, contains("label: const Text('Upload Document')"));
    expect(upload, contains("label: const Text('Photo / Camera')"));
    expect(
        upload,
        contains(
            "allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf']"));
    expect(auth, contains("httpsCallable('submitRiderDocument')"));
    expect(auth, contains('timeout: _documentUploadOperationTimeout'));
    expect(applicationCentre, contains('FilePicker.platform.pickFiles'));
    expect(applicationCentre, contains("'Upload Document'"));
    expect(applicationCentre, contains("'Photo / Camera'"));
    expect(
      applicationCentre,
      contains(
          "allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf']"),
    );
  });

  test('verification centre uses the canonical backend file policy', () {
    expect(RegExp("maxFileSize: '8 MiB'").allMatches(centre).length, 4);
    expect(centre, contains("maxFileSize: '10 MB'"));
    expect(centre, isNot(contains("acceptedFormats: 'JPG, PNG or HEIC'")));
    expect(
      centre,
      contains('const UploadIDView(idType: IdType.insurance)'),
    );
    expect(centre, contains(".where('riderId', isEqualTo: user.uid)"));
    expect(centre, isNot(contains(".where('uid', isEqualTo: user.uid)")));
    expect(centre, contains("raw == 'pending'"));
    expect(centre, contains("label: 'Under Review'"));
  });

  test('submission progress is separate from approval progress', () {
    expect(centre, contains('Documents submitted: \${state.submissionCount}'));
    expect(centre, contains('Verified: \${state.verifiedCount}'));
    expect(centre,
        contains('double get progress => submissionCount / requiredCount'));
    expect(
        centre,
        contains(
            'All required documents submitted. Some checks are still under review.'));
    expect(centre, contains("'Verification Under Review'"));
    expect(centre, contains('onPressed: state.hasActionableItem'));
    expect(centre, contains("raw == 'action_required'"));
  });

  test('vehicle status reads the backend canonical registration type', () {
    expect(centre, contains("'registration_v5c'"));
    expect(centre, contains("'vehicle_registration'"));
    expect(centre, contains("status: _statusFromDoc(vehicleDoc)"));
    expect(centre, contains('_documentUpdatedAt(doc).isAfter'));
  });

  test('document preview has no app screenshot or shared capture input', () {
    expect(upload, isNot(contains('RepaintBoundary')));
    expect(upload, isNot(contains('toImage(')));
    expect(upload, isNot(contains('screenshot')));
    expect(upload, contains('Image.file('));
    expect(upload, contains('ValueKey(selected.path)'));
  });
}
