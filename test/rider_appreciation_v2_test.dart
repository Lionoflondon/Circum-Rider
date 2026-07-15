import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider shell listens for canonical appreciation records', () {
    final shell =
        File('lib/app/bottom_nav/view/app_nav.dart').readAsStringSync();
    final view =
        File('lib/app/ratings/rider_appreciation.dart').readAsStringSync();
    expect(shell, contains('RiderAppreciationListener'));
    expect(view, contains("collection('driverRatings')"));
    expect(view, contains("collection('deliveryTips')"));
    expect(view, contains("collection('riderEarnings')"));
  });

  test('Rider experience mirrors rating, feedback, tip and wallet', () {
    final source =
        File('lib/app/ratings/rider_appreciation.dart').readAsStringSync();
    expect(source, contains("You made someone's day."));
    expect(source, contains('Tip received'));
    expect(source, contains("Today's Earnings"));
    expect(source, contains('Average Rating'));
    expect(source, contains('Lifetime Ratings'));
    expect(source, contains('Continue'));
  });

  test('Rider appreciation performs no operational writes', () {
    final source =
        File('lib/app/ratings/rider_appreciation.dart').readAsStringSync();
    expect(source, isNot(contains('.set(')));
    expect(source, isNot(contains('.update(')));
    expect(source, isNot(contains('.add(')));
    final bloc = File('lib/app/home/bloc/home_bloc.dart').readAsStringSync();
    expect(bloc, isNot(contains('_handleRateUser')));
  });
}
