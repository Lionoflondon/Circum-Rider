import 'dart:async';

import 'package:circum_rider/app/onboarding/rider_application_centre.dart';
import 'package:circum_rider/app/rider_shell/rider_vehicle_updates.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vehicle save calls backend with editable fields only', () async {
    Map<String, dynamic>? payload;
    await saveRiderVehicles([
      {
        'type': 'Motorcycle',
        'registration': ' AB12 CDE ',
        'make': 'Test',
        'approvalStatus': 'approved',
        'approved': true,
        'verificationStatus': 'verified',
        'dispatchEligible': true,
        'riderRank': 'sentinel',
        'trustPoints': 100,
        'primary': false,
      }
    ], updateProfile: (data) async {
      payload = data;
      return {'ok': true};
    });
    final savedPayload = payload!;
    expect(savedPayload['vehicleType'], 'motorbike');
    expect(savedPayload['vehicleRegistration'], 'AB12 CDE');
    expect((savedPayload['vehicles'] as List).single, {
      'type': 'motorbike',
      'registration': 'AB12 CDE',
      'make': 'Test',
      'model': '',
      'colour': '',
      'year': '',
      'ownershipStatus': '',
      'primary': true,
    });
    expect(
        savedPayload.keys,
        unorderedEquals([
          'vehicles',
          'vehicleType',
          'vehicleRegistration',
          'vehicleColour',
          'vehicleMakeModel'
        ]));
  });
  test(
      'canonical vehicle data rehydrates and edits preserve the chosen primary',
      () async {
    final values = riderEditableVehicles({
      'vehicles': [
        {
          'type': 'car',
          'registration': 'CAR 1',
          'make': 'Old',
          'primary': true
        },
        {'type': 'van', 'registration': 'VAN 2', 'make': 'Van'},
      ]
    });
    expect(values.first['manufacturer'], 'Old');
    values[0]['primary'] = false;
    values[1]['primary'] = true;
    values[1]['manufacturer'] = 'Edited';
    Map<String, dynamic>? payload;
    await saveRiderVehicles(values, updateProfile: (data) async {
      payload = data;
      return {'ok': true};
    });
    expect(payload!['vehicleType'], 'van');
    expect(payload!['vehicleMakeModel'], 'Edited');
    expect(
        riderEditableVehicles({
          'vehicle': {'type': 'car', 'plateNumber': 'LEGACY'}
        }).single['registration'],
        'LEGACY');
  });
  test('backend errors propagate so the form can retain values for retry',
      () async {
    final vehicles = [
      {'type': 'car', 'registration': 'AB12 CDE'}
    ];
    await expectLater(
        saveRiderVehicles(vehicles, updateProfile: (_) async {
          throw FirebaseFunctionsException(
              code: 'unavailable', message: 'Offline');
        }),
        throwsA(isA<FirebaseFunctionsException>()));
    Map<String, dynamic>? payload;
    await saveRiderVehicles(vehicles, updateProfile: (data) async {
      payload = data;
      return {'ok': true};
    });
    expect(payload!['vehicleType'], 'car');
  });
  test('empty, excessive, and invalid vehicles cannot be silently truncated',
      () async {
    for (final vehicles in <List<Map<String, dynamic>>>[
      [],
      List.generate(3, (_) => {'type': 'car', 'registration': 'AB12 CDE'}),
      [
        {'type': 'bicycle', 'registration': 'AB12 CDE'}
      ],
      [
        {'type': 'van'}
      ],
    ]) {
      await expectLater(saveRiderVehicles(vehicles), throwsStateError);
    }
  });
  test('rehydration preserves primary ordering and legacy manufacturer', () {
    final values = riderEditableVehicles({
      'vehicles': [
        {'type': 'van'},
        {'type': 'car', 'primary': true, 'manufacturer': 'Test'},
      ]
    });
    expect(values.first['type'], 'car');
    expect(values.first['make'], 'Test');
  });
  testWidgets('callable timeout is bounded', (tester) async {
    Object? failure;
    final pending = saveRiderVehicles([
      {'type': 'car', 'registration': 'AB12 CDE'}
    ], updateProfile: (_) => Completer<Map<String, dynamic>>().future)
        .catchError((Object error) {
      failure = error;
    });
    await tester.pump(const Duration(seconds: 21));
    await pending;
    expect(failure, isA<TimeoutException>());
  });
  testWidgets('failed save retains editable form and enables retry',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
        home: RiderVehicleApplicationForm(
      load: () async => [
        {'type': 'car', 'registration': 'AB12 CDE'}
      ],
      save: (_) async {
        attempts++;
        throw StateError('Network unavailable. Retry.');
      },
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save vehicles'));
    await tester.tap(find.text('Save vehicles'));
    await tester.pumpAndSettle();
    expect(find.text('Network unavailable. Retry.'), findsOneWidget);
    expect(find.text('AB12 CDE'), findsOneWidget);
    await tester.tap(find.text('Save vehicles'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });
}
