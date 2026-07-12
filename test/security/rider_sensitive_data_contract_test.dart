import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider auth and home code do not persist or log sensitive data', () {
    final root = Directory.current;
    final sensitiveSources = <File>[
      File('${root.path}/lib/app/authentication/bloc/auth_bloc.dart'),
      File('${root.path}/lib/app/home/bloc/home_bloc.dart'),
    ];

    for (final source in sensitiveSources) {
      expect(source.existsSync(), isTrue, reason: source.path);
      final body = source.readAsStringSync();

      expect(body, isNot(contains("storage.write(key: 'password'")),
          reason: source.path);
      expect(body, isNot(contains('storage.write(key: "password"')),
          reason: source.path);
      expect(body, isNot(contains('readAll())["password"]')),
          reason: source.path);
      expect(body, isNot(contains("readAll())['password']")),
          reason: source.path);
      expect(body, isNot(contains('credential?.accessToken')),
          reason: source.path);
      expect(body, isNot(contains('credential?.token')), reason: source.path);
      expect(body, isNot(contains('FCMToken:')), reason: source.path);
      expect(body, isNot(contains('fcmToken Is null')), reason: source.path);
      expect(body, isNot(contains('apnsToken:')), reason: source.path);
    }
  });

  test('release-critical Rider paths do not use raw print diagnostics', () {
    final root = Directory.current;
    final releaseCriticalSources = <File>[
      File('${root.path}/lib/app/home/bloc/home_bloc.dart'),
      File('${root.path}/lib/app/tracking/rider_live_tracking_controller.dart'),
    ];

    for (final source in releaseCriticalSources) {
      expect(source.existsSync(), isTrue, reason: source.path);
      final executableLines = source
          .readAsLinesSync()
          .map((line) => line.trimLeft())
          .where((line) => !line.startsWith('//'))
          .join('\n');

      expect(executableLines, isNot(contains('print(')), reason: source.path);
    }
  });
}
