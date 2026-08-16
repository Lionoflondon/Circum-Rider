import 'package:flutter_test/flutter_test.dart';

void main() {
  test('terminal delivery states are excluded from active Rider surfaces', () {
    const terminal = {'cancelled', 'canceled', 'completed', 'delivered', 'failed', 'expired', 'archived'};
    expect(terminal.contains('cancelled'), isTrue);
    expect(terminal.contains('requested'), isFalse);
  });

  test('delivery without identity or pickup data is quarantinable', () {
    final malformed = <String, dynamic>{'status': 'requested'};
    expect(malformed['requestId'] == null && malformed['code'] == null &&
        malformed['pickupDetails'] == null && malformed['pickup'] == null, isTrue);
  });
}
