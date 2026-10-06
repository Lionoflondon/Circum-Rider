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
  test(
      'native engines share providers and only simulator debug defaults change',
      () {
    const root =
        'third_party/firebase_app_check/ios/firebase_app_check/Sources/firebase_app_check/';
    final plugin =
        File('${root}FLTFirebaseAppCheckPlugin.m').readAsStringSync();
    final factory =
        File('${root}FLTAppCheckProviderFactory.m').readAsStringSync();
    expect(plugin, contains('dispatch_once(&providerFactoryOnce'));
    expect(plugin, contains('self->providerFactory = sharedProviderFactory'));
    expect(factory, contains('#if DEBUG && TARGET_OS_SIMULATOR'));
    expect(factory, contains('providerName:@"debug"'));
    expect(
        factory,
        contains(
            '#else\n    [provider configure:app providerName:@"deviceCheck"];\n#endif'));
  });
}
