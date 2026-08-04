import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepted delivery restoration tolerates an empty location cache', () {
    final source = File('lib/app/home/bloc/home_bloc.dart').readAsStringSync();

    expect(source, isNot(contains('lat: riderLat!, lng: riderLng!')));
    expect(source, contains('if (riderLat != null && riderLng != null)'));
    expect(source, contains('activeRequest: activeRequest'));
    expect(source, contains("'recipient_verification'"));
    expect(source, contains('activeDocs.take(1)'));
    expect(source, contains('bMillis.compareTo(aMillis)'));
  });

  test('assigned active delivery is restored ahead of the available feed', () {
    final jobs = File(
      'lib/app/rider_jobs/rider_job_offer_screen.dart',
    ).readAsStringSync();
    final nav = File('lib/app/bottom_nav/view/app_nav.dart').readAsStringSync();

    expect(jobs, contains('final activeRequest = home.activeRequest'));
    expect(jobs, contains('final activeRequestData = home.activeRequestData'));
    expect(jobs, contains('data: activeRequestData'));
    expect(jobs, contains('RiderAcceptedJobScreen'));
    expect(nav, contains('BlocListener<HomeBloc, HomeState>'));
    expect(nav, contains('current.activeRequest != null'));
    expect(nav, contains('select(1)'));
  });
}
