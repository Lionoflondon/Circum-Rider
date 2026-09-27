import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Jobs keeps Firestore Web listeners stable across rebuilds', () {
    final source = File(
      'lib/app/rider_jobs/rider_job_offer_screen.dart',
    ).readAsStringSync();

    expect(source, contains('_riderSnapshotStream'));
    expect(source, contains('_profileSnapshotStream'));
    expect(source, contains('_presenceSnapshotStream'));
    expect(source, contains('stream: _riderSnapshotStream'));
    expect(source, contains('stream: _profileSnapshotStream'));
    expect(source, contains('stream: _presenceSnapshotStream'));
    expect(
      source,
      isNot(contains(
          "stream:\n                    _firestore.collection('riders')")),
    );
  });
}
