import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vehicle view projects one backend-authoritative active vehicle', () {
    final source = File('lib/app/rider_shell/rider_profile_details_view.dart')
        .readAsStringSync();

    expect(source, contains("useFallback('type', data['vehicleType']"));
    expect(source, contains("'registration', data['vehicleRegistration']"));
    expect(source, contains("vehicle['primary'] = true"));
    expect(source, contains("vehicle['active'] = true"));
    expect(source, contains("text == 'null' ? '' : text"));
    expect(source, isNot(contains("title: const Text('Delete vehicle?')")));
  });
}
