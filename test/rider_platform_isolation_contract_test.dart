import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider mobile and web entrypoints do not share startup configuration',
      () {
    final mobile = File('lib/main.dart').readAsStringSync();
    final web = File('lib/main_rider_web.dart').readAsStringSync();
    final webAppCheck =
        File('lib/app/security/rider_app_check.dart').readAsStringSync();

    expect(mobile, isNot(contains('kIsWeb')));
    expect(mobile, isNot(contains('RIDER_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY')));
    expect(web, isNot(contains("import 'package:circum_rider/main.dart'")));
    expect(web, contains("import 'package:circum_rider/rider_app.dart'"));
    expect(webAppCheck, contains('RIDER_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY'));
  });
}
