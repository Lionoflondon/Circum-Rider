import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source =
      File('lib/app/authentication/bloc/auth_bloc.dart').readAsStringSync();
  test('active reset event has bounded success and explicit terminal errors',
      () {
    final handler = source.substring(source.indexOf('on<ResetPassword>'));
    expect(handler, contains('.timeout(_authOperationTimeout)'));
    expect(handler, contains('Status.passwordResetEmailSent'));
    expect(handler, contains('RiderAuthError.messageFor(error.code)'));
    expect(handler, contains('on TimeoutException'));
    expect(handler, contains('Password reset took too long.'));
    expect(handler,
        contains('We could not send the reset email. Please try again.'));
    expect(RegExp('isLoading: false').allMatches(handler).length,
        greaterThanOrEqualTo(4));
  });
  for (final event in ['UpdateFirstName', 'UpdateLastName']) {
    test(
        '$event is authenticated, bounded and only updates local name after success',
        () {
      final start = source.indexOf('on<$event>');
      final end = source.indexOf('\n    on<', start + 1);
      final handler = source.substring(start, end);
      expect(handler, contains('if (user == null)'));
      expect(handler, contains('.timeout(_authOperationTimeout)'));
      expect(handler, contains('on TimeoutException'));
      expect(handler, contains('error.safeMessage'));
      expect(handler,
          contains('Your name could not be updated. Please try again.'));
      expect(handler.indexOf('await user'),
          lessThan(handler.indexOf('emit(state.copyWith(username:')));
    });
  }
}
