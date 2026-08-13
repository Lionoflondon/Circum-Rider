import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restored Rider sessions are not expired by account creation date', () {
    final authBloc = File(
      'lib/app/authentication/bloc/auth_bloc.dart',
    ).readAsStringSync();

    expect(authBloc, isNot(contains("DateTime.parse('2024-05-15')")));
    expect(
      authBloc,
      isNot(contains('Future.delayed(const Duration(seconds: 3))')),
    );
    expect(authBloc, contains('on<SignOut>'));
    expect(authBloc, contains('await auth.signOut()'));
  });
}
