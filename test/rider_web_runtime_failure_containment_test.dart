import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'widget failures cannot masquerade as Rider startup or App Check failure',
      () {
    final source = File('lib/main_rider_web.dart').readAsStringSync();

    expect(source,
        contains('ErrorWidget.builder = (_) => const RiderWebRenderFailure()'));
    expect(source, contains('Reference: RDR-WEB-RENDER-001'));
    expect(source, isNot(contains('RDR-WEB-START-002')));

    final failureStart = source.indexOf('class RiderWebRenderFailure');
    final failureSource = source.substring(failureStart);
    expect(failureSource, isNot(contains('return MaterialApp(')));
    expect(failureSource, isNot(contains('home: Scaffold(')));
    expect(failureSource, contains('active delivery are still running'));
  });
}
