import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final applicationCentre =
      File('lib/app/onboarding/rider_application_centre.dart')
          .readAsStringSync();
  final authBloc =
      File('lib/app/authentication/bloc/auth_bloc.dart').readAsStringSync();

  test('Application Centre persists through backend callables only', () {
    expect(applicationCentre, contains("httpsCallable('updateRiderProfile')"));
    expect(applicationCentre,
        contains("httpsCallable('updateRiderApplicationSection')"));
    expect(applicationCentre, contains("httpsCallable('submitRiderDocument')"));
    expect(
        applicationCentre, contains("httpsCallable('submitRiderApplication')"));
    expect(applicationCentre, contains("'fileBase64': base64Encode(bytes)"));
    expect(applicationCentre, contains("'vehicles': capped"));
    expect(applicationCentre, isNot(contains('FirebaseStorage')));
    expect(applicationCentre, isNot(contains('.putData(')));
    expect(applicationCentre, isNot(contains('.putFile(')));
    for (final collection in [
      'riderApplications',
      'riderDocuments',
      'riderApplicationAudit',
    ]) {
      expect(
        RegExp("collection\\('$collection'\\)[^;{}]{0,180}\\.(set|update|add)")
            .hasMatch(applicationCentre),
        isFalse,
      );
    }
  });

  test('verification persistence uses submitRiderDocument, not client Storage',
      () {
    expect(authBloc, contains("httpsCallable('submitRiderDocument')"));
    expect(authBloc, contains("'fileBase64': base64Encode(bytes)"));
    expect(authBloc, isNot(contains('FirebaseStorage')));
    expect(authBloc, isNot(contains('.putData(')));
    expect(authBloc, isNot(contains('.putFile(')));
    for (final collection in [
      'riderApplications',
      'riderDocuments',
      'riderApplicationAudit',
    ]) {
      expect(
        RegExp("collection\\('$collection'\\)[^;{}]{0,180}\\.(set|update|add)")
            .hasMatch(authBloc),
        isFalse,
      );
    }
  });

  test('vehicle persistence includes the complete bounded form payload', () {
    expect(applicationCentre, contains('maxVehicles'));
    expect(applicationCentre, contains("'vehicleMakeModel'"));
    expect(applicationCentre, contains("'vehicleColour'"));
    expect(applicationCentre, contains("'vehicleRegistration'"));
  });
}
