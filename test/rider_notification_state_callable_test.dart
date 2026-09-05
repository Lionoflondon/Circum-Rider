import 'package:circum_rider/app/communication/rider_communication_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No direct Firestore writes allowed');
}

class _NoAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Authentication belongs to callable');
}

class _Result<T> implements HttpsCallableResult<T> {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Callable implements HttpsCallable {
  _Callable(this.owner);
  final _Functions owner;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    if (owner.fail) throw StateError('offline');
    owner.payloads.add(Map<String, dynamic>.from(parameters as Map));
    return _Result<T>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Functions implements FirebaseFunctions {
  final payloads = <Map<String, dynamic>>[];
  bool fail = false;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    expect(name, 'updateRiderNotificationState');
    return _Callable(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late _Functions functions;
  late RiderCommunicationService service;
  setUp(() {
    functions = _Functions();
    service = RiderCommunicationService(
        firestore: _NoFirestore(), functions: functions, auth: _NoAuth());
  });
  test('read archive and delete use only the safe backend callable', () async {
    await service.markNotificationRead('one');
    await service.archiveNotification('two');
    await service.deleteNotification('three');
    expect(functions.payloads, [
      {
        'notificationIds': ['one'],
        'action': 'mark_read'
      },
      {
        'notificationIds': ['two'],
        'action': 'archive'
      },
      {
        'notificationIds': ['three'],
        'action': 'delete'
      },
    ]);
  });
  test(
      'mark all deduplicates and batches within the server limit without losing IDs',
      () async {
    await service.markAllNotificationsRead(
        ['', ' n0 ', ...List.generate(201, (i) => 'n$i')]);
    expect(functions.payloads.map((p) => (p['notificationIds'] as List).length),
        [100, 100, 1]);
    expect(
        functions.payloads
            .expand((p) => p['notificationIds'] as List)
            .toSet()
            .length,
        201);
  });
  test('empty list is safe and callable errors stay visible to the UI guard',
      () async {
    await service.markAllNotificationsRead([]);
    expect(functions.payloads, isEmpty);
    functions.fail = true;
    await expectLater(service.archiveNotification('one'), throwsStateError);
  });
}
