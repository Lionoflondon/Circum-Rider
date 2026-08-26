import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/app/onboarding/rider_application_centre.dart')
      .readAsStringSync();

  test('payout row opens the existing earnings and payout surface', () {
    expect(source, contains("case 'payout_details':"));
    expect(source, contains('const EarningsView()'));
    expect(source, isNot(contains("'Payout setup status will update")));
  });

  test('document submission exposes loading, success, and failure states', () {
    expect(source, contains('bool _submitted = false;'));
    expect(source, contains('bool _uploading = false;'));
    expect(source, contains('Submitted'));
    expect(source, contains('Your document has been submitted for review.'));
    expect(
        source, contains('The document was not submitted. Please try again.'));
    expect(source,
        contains('Future<bool> Function(String type, XFile file) upload'));
  });

  test('application progress is derived from required persisted sections', () {
    expect(source, contains('_requiredProgress('));
    expect(source, contains("'personal_details'"));
    expect(source, contains("'home_address'"));
    expect(source, contains("'vehicle_documents'"));
    expect(source, contains('requiredProgress.fraction'));
    expect(source, contains('completed: completed'));
    expect(source,
        contains('applicationSubmitted: progress.applicationSubmitted'));
  });

  test('submission is available independently of completion or declarations', () {
    expect(source, contains("httpsCallable('submitRiderApplication')"));
    expect(source, contains("'idempotencyKey': 'rider_application:\$uid'"));
    expect(source, isNot(contains('rightToWorkConfirmed')));
    expect(source, isNot(contains('sealedPackageConsent')));
  });

  test('personal and vehicle forms close only after awaited save success', () {
    expect(source, contains('await widget.save({'));
    expect(source, contains('await widget.save(['));
    expect(source, contains('Navigator.pop(context, true)'));
    expect(source, contains('Save and continue'));
    expect(source, contains('Save vehicles'));
  });

  test('every visible Application Centre action has an executable route', () {
    for (final key in [
      'personal_details',
      'home_address',
      'contact_details',
      'identity_verification',
      'right_to_work',
      'vehicle_details',
      'vehicle_documents',
      'payout_details',
      'roth_wallet_setup',
      'application_messages',
      'review_status',
    ]) {
      expect(source, contains("case '$key':"));
    }
    expect(source, contains('Navigator.maybePop(context)'));
    expect(source, contains('_ApplicationReviewStatusView'));
    expect(source, contains("chatId: 'admin_rider_\${uid}_application'"));
  });
}
