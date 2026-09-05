import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circum_rider/app/onboarding/rider_onboarding_policy.dart';
import 'package:circum_rider/app/onboarding/rider_application_centre.dart';
import 'package:circum_rider/app/rider_account/rider_account_state.dart';
import 'package:circum_rider/app/authentication/rider_auth_error.dart';

void main() {
  test('default pending flags are not submitted documents or an application',
      () {
    final progress = RiderApprovalProgress.fromBackend(
        accountExists: true,
        firebaseEmailVerified: false,
        rider: {
          'approvalStatus': 'pending',
          'verificationStatus': 'pending',
          'vehicle': {}
        });
    expect(progress.documentsSubmitted, false);
    expect(progress.applicationSubmitted, false);
    expect(progress.vehicleDetails, false);
  });
  test(
      'canonical upload truth updates progress and failed/rejected uploads do not',
      () {
    for (final state in ['pending', 'uploaded', 'submitted', 'approved']) {
      final progress = RiderApprovalProgress.fromBackend(
          accountExists: true,
          firebaseEmailVerified: false,
          rider: {},
          documents: [
            {'type': 'identity', 'status': state}
          ]);
      expect(progress.documentsSubmitted, true);
    }
    for (final state in ['failed', 'rejected', 'needs_information']) {
      expect(
          RiderApprovalProgress.fromBackend(
              accountExists: true,
              firebaseEmailVerified: false,
              rider: {},
              documents: [
                {'type': 'identity', 'status': state}
              ]).documentsSubmitted,
          false);
    }
    expect(riderDocumentType('passport'), 'identity');
    expect(riderDocumentType('v5c'), 'registration_v5c');
    expect(riderApplicationStatusFrom('needs_information'),
        RiderApplicationSectionStatus.needsAttention);
    expect(riderApplicationStatusFrom('pending'),
        RiderApplicationSectionStatus.submitted);
  });
  test('backend profile document mirror updates the submitted status screen',
      () {
    expect(
        RiderApprovalProgress.fromBackend(
            accountExists: true,
            firebaseEmailVerified: false,
            rider: {
              'verificationDocuments': {
                'identity': {'type': 'identity', 'status': 'pending'}
              }
            }).documentsSubmitted,
        true);
  });
  test('a newer successful replacement clears an older rejected document', () {
    final docs = latestRiderDocuments([
      {
        'type': 'identity',
        'status': 'rejected',
        'uploadedAt': DateTime(2026, 1, 1)
      },
      {
        'type': 'passport',
        'status': 'pending',
        'uploadedAt': DateTime(2026, 1, 2)
      },
    ]);
    expect(docs.length, 1);
    expect(riderDocumentSubmitted(docs.single), true);
  });
  test('every accepted extension has the same eight MiB limit', () {
    for (final extension in ['pdf', 'jpg', 'jpeg', 'png', 'webp']) {
      expect(riderUploadError('file.$extension', 8 * 1024 * 1024), null);
      expect(riderUploadError('file.$extension', 8 * 1024 * 1024 + 1),
          'Documents must be 8 MiB or smaller.');
    }
    expect(riderUploadError('file.exe', 10), isNotNull);
    expect(riderUploadError('file.pdf', 0), isNotNull);
  });
  for (final entry in riderVehicleChoices.entries) {
    testWidgets('${entry.value} picker persists canonical ${entry.key}',
        (tester) async {
      List<Map<String, dynamic>>? saved;
      await tester.pumpWidget(MaterialApp(
          home: RiderVehicleApplicationForm(
              load: () async => [
                    {'type': entry.key, 'registration': 'AB12 CDE'}
                  ],
              save: (vehicles) async {
                saved = vehicles;
              })));
      await tester.pumpAndSettle();
      final picker = tester.widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>));
      expect(picker.initialValue, entry.key);
      await tester.drag(find.byType(ListView), const Offset(0, -650));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save vehicles'));
      await tester.pumpAndSettle();
      expect(saved!.single['type'], entry.key);
    });
  }
  test('legacy aliases rehydrate safely and unknown vehicles require selection',
      () {
    expect(riderVehicleValue('Motorcycle'), 'motorbike');
    expect(riderVehicleValue('electric bike'), null);
    expect(riderVehicleValue('caravan'), null);
  });
  test('needs information is visible but never grants operational approval',
      () {
    final state = RiderAccountStateResolver.resolve(
        {'approvalStatus': 'needs_information'});
    expect(state, RiderAccountState.moreInformationRequired);
    expect(RiderAccountStateResolver.canOperate(state), false);
    expect(
        RiderAccountStateResolver.canOperate(RiderAccountState.pendingReview),
        false);
  });
  test('wrong surface is clearly explained and auth checks run before success',
      () {
    expect(RiderAuthError.messageFor('wrong-surface'),
        'This account belongs to another Circum app. Sign in with a Rider account.');
    final source =
        File('lib/app/authentication/bloc/auth_bloc.dart').readAsStringSync();
    expect(source, contains("httpsCallable('verifyRiderAccountAccess')"));
    expect(
        source.split('await verifyRiderSurface(userCredential.user);').length,
        4);
    expect(source, contains('await verifyRiderSurface(user);'));
    final guard = source.substring(
        source.indexOf('Future<void> verifyRiderSurface('),
        source.indexOf('Future<void> upsertRiderOnboarding('));
    expect(guard, contains("access.data['profileExists'] == false"));
    expect(guard.indexOf("httpsCallable('verifyRiderAccountAccess')"),
        lessThan(guard.indexOf("httpsCallable('updateRiderProfile')")));
  });
}
