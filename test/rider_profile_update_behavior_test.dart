import 'package:circum_rider/app/rider_shell/rider_profile_details_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile date normalization accepts canonical and display formats', () {
    expect(canonicalRiderDateOfBirth('1988-04-23'), '1988-04-23');
    expect(canonicalRiderDateOfBirth('23/04/1988'), '1988-04-23');
    expect(
      () => canonicalRiderDateOfBirth('31/02/1988'),
      throwsFormatException,
    );
  });
}
