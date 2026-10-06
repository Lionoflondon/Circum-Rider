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
}
