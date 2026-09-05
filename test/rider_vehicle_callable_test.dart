import 'dart:async';

import 'package:circum_rider/app/onboarding/rider_application_centre.dart';
import 'package:circum_rider/app/rider_shell/rider_vehicle_updates.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Functions implements FirebaseFunctions {
  Map<String, dynamic>? payload;
  Future<HttpsCallableResult<dynamic>> Function()? operation;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    expect(name, 'updateRiderProfile');
    return _Callable(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Callable implements HttpsCallable {
  _Callable(this.owner);
  final _Functions owner;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    owner.payload = Map<String, dynamic>.from(parameters as Map);
    if (owner.operation != null) await owner.operation!();
    return _Result<T>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Result<T> implements HttpsCallableResult<T> {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('vehicle save calls backend with editable fields only', () async {
    final functions = _Functions();
    await saveRiderVehicles(functions, [
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
    ]);
    final payload = functions.payload!;
    expect(payload['vehicleType'], 'motorbike');
    expect(payload['vehicleRegistration'], 'AB12 CDE');
    expect((payload['vehicles'] as List).single, {
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
        payload.keys,
        unorderedEquals([
          'vehicles',
          'vehicleType',
          'vehicleRegistration',
          'vehicleColour',
          'vehicleMakeModel'
        ]));
  });
  test('backend errors propagate so the form can retain values for retry',
      () async {
    final functions = _Functions()
      ..operation = () async => throw FirebaseFunctionsException(
          code: 'unavailable', message: 'Offline');
    final vehicles = [
      {'type': 'car', 'registration': 'AB12 CDE'}
    ];
    await expectLater(saveRiderVehicles(functions, vehicles),
        throwsA(isA<FirebaseFunctionsException>()));
    functions.operation = null;
    await saveRiderVehicles(functions, vehicles);
    expect(functions.payload!['vehicleType'], 'car');
  });
  test('empty, excessive, and invalid vehicles cannot be silently truncated',
      () async {
    final functions = _Functions();
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
      await expectLater(
          saveRiderVehicles(functions, vehicles), throwsStateError);
    }
    expect(functions.payload, isNull);
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
    final functions = _Functions()
      ..operation = () => Completer<HttpsCallableResult<dynamic>>().future;
    Object? failure;
    final pending = saveRiderVehicles(functions, [
      {'type': 'car', 'registration': 'AB12 CDE'}
    ]).catchError((Object error) {
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
