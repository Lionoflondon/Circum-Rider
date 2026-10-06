import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native App Check provider is installed before Firebase initialization',
      () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final configure = source.indexOf('FirebaseApp.configure()');
    expect(source.indexOf('GeneratedPluginRegistrant.register(with: self)'),
        greaterThan(configure));
    expect(source, contains('if FirebaseApp.app() == nil'));
    final debug = source.indexOf('AppCheckDebugProviderFactory()');
    expect(debug, lessThan(configure));
    expect(source, contains('#if DEBUG && targetEnvironment(simulator)'));
    expect(source.indexOf('#endif', debug), lessThan(configure));
  });
  test('Runner enables Swift DEBUG only in the development build', () {
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final start = project.indexOf('97C147061CF9000F007C117D /* Debug */ = {');
    final releaseStart =
        project.indexOf('97C147071CF9000F007C117D /* Release */ = {', start);
    final debug = project.substring(start, releaseStart);
    final release = project.substring(
        releaseStart, project.indexOf('name = Release;', releaseStart));
    expect(
        debug,
        contains(
            r'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) DEBUG";'));
    expect(release, isNot(contains('SWIFT_ACTIVE_COMPILATION_CONDITIONS')));
  });
}
