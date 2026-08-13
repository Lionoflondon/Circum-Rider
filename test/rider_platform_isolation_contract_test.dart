import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider mobile and Web keep platform startup ownership isolated', () {
    final mobile = File('lib/main.dart').readAsStringSync();
    final web = File('lib/main_rider_web.dart').readAsStringSync();
    final root = File('lib/rider_app.dart').readAsStringSync();
    final webAppCheck = File(
      'lib/app/security/rider_app_check.dart',
    ).readAsStringSync();
    final mobileAppCheck = File(
      'lib/app/security/circum_app_check.dart',
    ).readAsStringSync();
    final notifications =
        File('lib/helper/notifications_helper.dart').readAsStringSync();

    expect(mobile, isNot(contains('kIsWeb')));
    expect(mobile, isNot(contains('main_rider_web.dart')));
    expect(mobile, isNot(contains('RIDER_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY')));
    expect(web, isNot(contains("package:circum_rider/main.dart")));
    expect(web, contains("package:circum_rider/rider_app.dart"));
    expect(web, isNot(contains('homeBloc: homeBloc')));
    expect(mobile, contains('CircumRider(homeBloc: homeBloc)'));
    expect(root, contains('widget.homeBloc ?? HomeBloc()'));
    expect(root, isNot(contains('initializeRiderAppCheck')));
    expect(root, isNot(contains('initializeCircumAppCheck')));
    expect(webAppCheck, contains('RIDER_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY'));
    expect(webAppCheck, isNot(contains('AndroidProvider')));
    expect(webAppCheck, isNot(contains('AppleProvider')));
    expect(mobileAppCheck, contains('AndroidProvider'));
    expect(mobileAppCheck, contains('AppleProvider'));
    expect(mobileAppCheck, isNot(contains('ReCaptchaEnterpriseProvider')));
    expect(mobileAppCheck, isNot(contains('webProvider')));
    expect(notifications, isNot(contains("import '../main.dart'")));
    expect(notifications, contains('NotificationService(this.plugin)'));
  });
}
