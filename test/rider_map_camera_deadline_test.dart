import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/app/home/view/maps_view.dart').readAsStringSync();
  test('map fit bounds controller creation and native camera animation', () {
    final method = source.substring(
        source.indexOf('Future<void> setMapFitToTour'),
        source.indexOf('Future<void> changeCameraPosition'));
    expect(
        RegExp(r'\.timeout\(_mapControllerTimeout\)').allMatches(method).length,
        2);
    expect(method, contains('on TimeoutException'));
    expect(method, contains('catch (_)'));
  });
  test('camera reposition bounds controller creation and native animation', () {
    final method = source.substring(
        source.indexOf('Future<void> changeCameraPosition'),
        source.indexOf('@override\n  Widget build'));
    expect(
        RegExp(r'\.timeout\(_mapControllerTimeout\)').allMatches(method).length,
        2);
    expect(method, contains('on TimeoutException'));
    expect(method, contains('catch (_)'));
  });
}
