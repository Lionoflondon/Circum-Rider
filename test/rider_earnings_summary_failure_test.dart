import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circum_rider/app/account/repo/rider_earnings_summary_loader.dart';

void main() {
  test('early App Check failure is observed and still reaches a late consumer',
      () async {
    final escaped = <Object>[];
    final error = FirebaseException(
        plugin: 'firebase_app_check', code: 'permission-denied');
    late Future<Map<String, dynamic>> future;
    final done = Completer<void>();
    runZonedGuarded(() async {
      future = loadRiderEarningsSummary(
          currentUid: () => 'rider', load: () async => throw error);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await expectLater(future, throwsA(same(error)));
      done.complete();
    }, (error, _) {
      escaped.add(error);
    });
    await done.future;
    expect(escaped, isEmpty);
  });
  test('retry can succeed without fabricating a zero summary on failure',
      () async {
    var calls = 0;
    Future<dynamic> load() async {
      if (++calls == 1) throw StateError('offline');
      return {'storedAvailable': 7};
    }

    await expectLater(
        loadRiderEarningsSummary(currentUid: () => 'rider', load: load),
        throwsStateError);
    expect(
        await loadRiderEarningsSummary(currentUid: () => 'rider', load: load),
        {'storedAvailable': 7});
  });
  test('signed out does not request an App Check token or backend summary',
      () async {
    var calls = 0;
    await expectLater(
        loadRiderEarningsSummary(
            currentUid: () => null,
            load: () async {
              calls++;
              return {};
            }),
        throwsStateError);
    expect(calls, 0);
  });
  test('an account change rejects a delayed earnings response', () async {
    var uid = 'rider';
    final response = Completer<dynamic>();
    final future = loadRiderEarningsSummary(
        currentUid: () => uid, load: () => response.future);
    uid = 'different';
    response.complete({'storedAvailable': 99});
    await expectLater(future, throwsStateError);
  });
  test('a timed out summary is observed and delivered as an error', () async {
    await expectLater(
        loadRiderEarningsSummary(
            currentUid: () => 'rider',
            load: () => Completer<dynamic>().future,
            timeout: const Duration(milliseconds: 5)),
        throwsA(isA<TimeoutException>()));
  });
}
