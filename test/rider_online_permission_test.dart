import 'package:circum_rider/app/home/rider_availability_action.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  for (final permission in [
    LocationPermission.whileInUse,
    LocationPermission.always,
    LocationPermission.deniedForever,
  ]) {
    test('$permission does not trigger another permission prompt', () async {
      final result = await resolveRiderOnlinePermission(
        checkPermission: () async => permission,
        requestPermission: () async => throw StateError('unexpected prompt'),
        disclose: () async => throw StateError('unexpected disclosure'),
      );
      expect(result, permission);
    });
  }

  test('explicit online action discloses before requesting denied permission',
      () async {
    final calls = <String>[];
    final result = await resolveRiderOnlinePermission(
      checkPermission: () async => LocationPermission.denied,
      disclose: () async {
        calls.add('disclose');
        return true;
      },
      requestPermission: () async {
        calls.add('request');
        return LocationPermission.whileInUse;
      },
    );
    expect(calls, ['disclose', 'request']);
    expect(result, LocationPermission.whileInUse);
  });

  test('declining disclosure cancels online action without OS prompt',
      () async {
    final result = await resolveRiderOnlinePermission(
      checkPermission: () async => LocationPermission.denied,
      disclose: () async => false,
      requestPermission: () async => throw StateError('unexpected prompt'),
    );
    expect(result, isNull);
  });

  test('OS refusal remains denied and cannot grant location implicitly',
      () async {
    final result = await resolveRiderOnlinePermission(
      checkPermission: () async => LocationPermission.denied,
      disclose: () async => true,
      requestPermission: () async => LocationPermission.denied,
    );
    expect(result, LocationPermission.denied);
  });
}
