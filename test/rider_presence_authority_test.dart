import 'package:circum_rider/app/home/rider_presence_authority.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('healthy acknowledged backend presence is online', () {
    expect(
      isAuthoritativeRiderPresenceOnline({
        'isOnline': true,
        'availabilityStatus': 'available',
        'presenceState': 'fresh',
        'connectionStatus': 'connected',
        'dispatchEligible': true,
      }),
      isTrue,
    );
  });

  test('offline connectivity cannot be presented as online', () {
    expect(
      isAuthoritativeRiderPresenceOnline({
        'isOnline': true,
        'availabilityStatus': 'available',
        'presenceState': 'fresh',
        'connectionStatus': 'offline',
        'dispatchEligible': true,
      }),
      isFalse,
    );
  });

  test('stale backend presence cannot be presented as online', () {
    expect(
      isAuthoritativeRiderPresenceOnline({
        'isOnline': true,
        'availabilityStatus': 'available',
        'presenceState': 'stale',
        'connectionStatus': 'stale',
        'dispatchEligible': false,
      }),
      isFalse,
    );
  });

  test('busy acknowledged presence remains online', () {
    expect(
      isAuthoritativeRiderPresenceOnline({
        'isOnline': true,
        'availabilityStatus': 'busy',
        'presenceState': 'fresh',
        'connectionStatus': 'connected',
      }),
      isTrue,
    );
  });
}
