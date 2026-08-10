import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active delivery restoration uses the secure Rider projection', () {
    final source = File('lib/app/home/bloc/home_bloc.dart').readAsStringSync();
    final restoreStart = source.indexOf('void _handleCheckForActiveRequest');
    expect(restoreStart, greaterThanOrEqualTo(0));
    final restoreSource = source.substring(restoreStart);

    expect(restoreSource, contains("httpsCallable('getAvailableRequests')"));
    expect(restoreSource, contains("payload['activeJobs']"));
    expect(
      restoreSource,
      isNot(contains("collection('deliveryRequests')")),
    );
  });
}
