import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider Web uses the canonical App Check startup gate', () {
    final webMain = File('lib/main_rider_web.dart').readAsStringSync();
    final appCheck =
        File('lib/app/security/rider_app_check.dart').readAsStringSync();

    expect(webMain, contains('DefaultFirebaseOptions.web'));
    expect(webMain, contains('RiderWebStartupApp'));
    expect(webMain, contains('initializeRiderAppCheck'));
    expect(appCheck, contains('ReCaptchaEnterpriseProvider'));
    expect(appCheck, contains('RIDER_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY'));
    expect(appCheck, contains('RiderStartupBlocked'));
    expect(appCheck, isNot(contains('debugProvider')));
  });
}
