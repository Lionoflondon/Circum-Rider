import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circum_rider/app/account/bloc/account_bloc.dart';

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Auth implements FirebaseAuth {
  @override
  User? currentUser = _User('rider');
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Empty implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Collection implements CollectionReference<Map<String, dynamic>> {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) return this;
    if (invocation.memberName == #get)
      return Future<QuerySnapshot<Map<String, dynamic>>>.value(_Empty());
    throw UnimplementedError();
  }
}

class _Db implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
void main() {
  test(
      'duplicate cancellation taps use one captured exact ID and no withdrawal while pending',
      () async {
    final result = Completer<Map<String, dynamic>>();
    final calls = <Map<String, dynamic>>[];
    final bloc = AccountBloc(
        authentication: _Auth(),
        firestore: _Db(),
        payout: (name, data) {
          calls.add({'name': name, ...data});
          return result.future;
        });
    bloc.add(const CancelWithdrawalRequest(requestId: 'selected'));
    bloc.add(const CancelWithdrawalRequest(requestId: 'historical'));
    bloc.add(RequestWithdrawal(
        amount: '5',
        sortCode: '',
        accountNumber: '',
        address: '',
        bankName: '',
        saveAccountDetails: false));
    await tick();
    expect(calls, [
      {'name': 'cancelRiderWithdrawal', 'requestId': 'selected'}
    ]);
    result.complete({'status': 'cancelled'});
    await tick();
    await tick();
    await bloc.close();
  });
  test('an account change discards a delayed successful withdrawal response',
      () async {
    final auth = _Auth();
    final result = Completer<Map<String, dynamic>>();
    final bloc = AccountBloc(
        authentication: auth,
        firestore: _Db(),
        payout: (_, __) => result.future);
    bloc.add(RequestWithdrawal(
        amount: '5',
        sortCode: '',
        accountNumber: '',
        address: '',
        bankName: '',
        saveAccountDetails: false));
    await tick();
    auth.currentUser = _User('another-rider');
    result.complete({'amount': 5, 'requestId': 'private-old-request'});
    await tick();
    await tick();
    expect(bloc.state.withdrawRequest, isNull);
    expect(bloc.state.isWithdrawRequestActive, false);
    await bloc.close();
  });
}
