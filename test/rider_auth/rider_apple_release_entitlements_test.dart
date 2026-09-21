import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider release requests production Apple service environments', () {
    final entitlements =
        File('ios/Runner/RunnerRelease.entitlements').readAsStringSync();

    expect(
        entitlements, contains('<key>com.apple.developer.applesignin</key>'));
    expect(entitlements, contains('<string>Default</string>'));
    expect(
      RegExp(r'<string>production</string>').allMatches(entitlements),
      hasLength(2),
    );
    expect(entitlements, isNot(contains('<string>development</string>')));
  });

  test('Rider packages a privacy manifest without tracking', () {
    final manifest =
        File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    expect(manifest, contains('<key>NSPrivacyTracking</key>\n\t<false/>'));
    expect(manifest, contains('NSPrivacyAccessedAPITypes'));
    expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
  });

  test('Rider Maps uses a release-injected iOS configuration', () {
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(info, contains('<key>GoogleMapsApiKey</key>'));
    expect(info, contains(r'$(GOOGLE_MAPS_API_KEY)'));
    expect(delegate, contains('GoogleMapsApiKey'));
    expect(delegate, isNot(contains(RegExp(r'AIza[0-9A-Za-z_-]+'))));
  });
}
