import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'entry reuses canonical AuthBloc and contains no Rider-specific language',
    () {
      final source = File(
        'lib/app/onboarding/view/onboarding.dart',
      ).readAsStringSync();
      expect(source, contains('SignInWithGoogle'));
      expect(source, contains('SignInWithAppleAuth'));
      expect(source, contains('PhoneNumberChanged'));
      expect(source, contains('SignupEmailChanged'));
      expect(source, isNot(contains('Rider Login')));
      expect(source, isNot(contains('Become a Rider')));
      expect(source, isNot(contains('FirebaseAuth.instance')));
    },
  );
}
