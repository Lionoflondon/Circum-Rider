// Isolated SDK test doubles; these do not invoke Firebase transports.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:circum_rider/app/home/bloc/home_bloc.dart';
import 'package:circum_rider/app/home/models/dispatch_request.m..dart';

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Auth implements FirebaseAuth {
  @override
  User? currentUser = _User('rider');
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Messaging implements FirebaseMessaging {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Active implements DispatchRequest {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  Map<String, dynamic> data() => {'isOnline': false};
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Rows implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Ref implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.db);
  final _Db db;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      db.presence();
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.db);
  final _Db db;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => _Ref(db);
  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #where) return this;
    if (i.memberName == #get) return db.jobs();
    throw UnimplementedError();
  }
}

class _Db implements FirebaseFirestore {
  Future<DocumentSnapshot<Map<String, dynamic>>> Function() presence =
      () async => _Snapshot();
  Future<QuerySnapshot<Map<String, dynamic>>> Function() jobs =
      () async => _Rows();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this);
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final stage in ['presence', 'jobs']) {
    test('$stage read denial preserves known job and remains retryable',
        () async {
      final db = _Db();
      final auth = _Auth();
      var fail = true;
      final error = FirebaseException(
          plugin: 'cloud_firestore', code: 'permission-denied');
      if (stage == 'presence') {
        db.presence = () async {
          if (fail) {
            throw error;
          }
          return _Snapshot();
        };
      } else {
        db.jobs = () async {
          if (fail) {
            throw error;
          }
          return _Rows();
        };
      }
      final bloc = HomeBloc(
          authentication: auth, firestore: db, messaging: _Messaging());
      addTearDown(bloc.close);
      final active = _Active();
      bloc.state.activeRequest = active;
      final failed = bloc.stream
          .firstWhere((s) => s.dispatchReason == 'session_restore_failed');
      bloc.add(CheckForActiveRequest());
      final state = await failed.timeout(const Duration(seconds: 2));
      expect(state.activeRequest, same(active));
      expect(state.dispatchEligible, isFalse);
      expect(state.message, contains('Pull to refresh'));
      fail = false;
      final recovered = bloc.stream
          .firstWhere((s) => s.dispatchReason == null && s.message == null);
      bloc.add(CheckForActiveRequest());
      await recovered.timeout(const Duration(seconds: 2));
    });
  }
  test('delayed failure after account change cannot modify the new session',
      () async {
    final pending = Completer<DocumentSnapshot<Map<String, dynamic>>>();
    final db = _Db()..presence = () => pending.future;
    final auth = _Auth();
    final bloc =
        HomeBloc(authentication: auth, firestore: db, messaging: _Messaging());
    addTearDown(bloc.close);
    bloc.add(CheckForActiveRequest());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    auth.currentUser = _User('different');
    pending.completeError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.message, isNull);
    expect(bloc.state.dispatchReason, isNull);
  });
  test('an older failed refresh cannot overwrite a newer successful refresh',
      () async {
    final pending = Completer<DocumentSnapshot<Map<String, dynamic>>>();
    var reads = 0;
    final db = _Db()
      ..presence =
          () => ++reads == 1 ? pending.future : Future.value(_Snapshot());
    final bloc = HomeBloc(
        authentication: _Auth(), firestore: db, messaging: _Messaging());
    addTearDown(bloc.close);
    bloc.add(CheckForActiveRequest());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final success = bloc.stream.first;
    bloc.add(CheckForActiveRequest());
    await success.timeout(const Duration(seconds: 2));
    pending.completeError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.message, isNull);
    expect(bloc.state.dispatchReason, isNull);
  });
}
