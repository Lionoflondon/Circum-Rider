import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider Web loads its own Maps SDK and requires a release key', () {
    final index = File('web/index.html').readAsStringSync();
    final build = File('scripts/build_rider_web.sh').readAsStringSync();
    expect(index, contains('__RIDER_WEB_GOOGLE_MAPS_API_KEY__'));
    expect(index, contains('loading=async'));
    expect(build, contains('RIDER_WEB_GOOGLE_MAPS_API_KEY'));
  });

  test('canonical Rider Web maps use operational renderers', () {
    final offer = File('lib/app/rider_jobs/rider_job_offer_screen.dart').readAsStringSync();
    final active = File('lib/app/home/view/maps_view.dart').readAsStringSync();
    expect(offer, isNot(contains('if (kIsWeb) return const _MapFallback();')));
    expect(active, isNot(contains('if (kIsWeb)')));
    expect(offer, contains("widget.offer.raw['routeGeometry']"));
  });
}
