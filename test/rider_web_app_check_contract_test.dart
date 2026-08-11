import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider Web uses the canonical App Check startup gate', () {
    final webMain = File('lib/main_rider_web.dart').readAsStringSync();
    final appCheck =
        File('lib/app/security/rider_app_check.dart').readAsStringSync();

    expect(webMain, contains('DefaultFirebaseOptions.web'));
    expect(webMain, contains('RiderWebStartupApp'));
    expect(webMain, contains('RiderWebBootstrapGate'));
    expect(webMain, contains('runApp(const RiderWebBootstrapGate())'));
    expect(webMain, contains('RiderWebSecurityGate'));
    expect(webMain, contains('AbsorbPointer'));
    expect(webMain, contains('RiderWebSecurityStatus.initializing'));
    expect(webMain, contains('RiderWebSecurityStatus.ready'));
    expect(webMain, contains('RiderWebSecurityStatus.retryableFailure'));
    expect(webMain, contains('Security verification unavailable'));
    expect(webMain, contains('Retry'));
    expect(webMain, contains('initializeRiderAppCheck'));
    expect(webMain, contains('ErrorWidget.builder'));
    expect(webMain, contains('RiderWebRuntimeFailure'));
    expect(appCheck, contains('ReCaptchaEnterpriseProvider'));
    expect(appCheck, contains('RIDER_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY'));
    expect(appCheck, contains('RiderAppCheckStartup.blocked'));
    expect(appCheck, contains('blockStartup'));
    expect(appCheck, isNot(contains('debugProvider')));
  });
}
