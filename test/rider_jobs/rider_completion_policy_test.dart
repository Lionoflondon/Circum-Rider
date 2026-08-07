import 'package:circum_rider/app/rider_jobs/rider_completion_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ordinaryVerification = {
    'pickupVerificationRequired': false,
    'recipientPinRequired': false,
    'handoverEvidenceRequired': false,
  };

  test('product labels do not override an explicit ordinary policy', () {
    for (final product in ['business', 'health_plus', 'gift']) {
      final policy = RiderCompletionPolicy.fromRaw({
        'serviceType': product,
        'vanguardProtocolEnabled': false,
        'iris': {'verification': ordinaryVerification},
      });
      expect(policy.pickupVerificationRequired, isFalse, reason: product);
      expect(policy.receiverVerificationRequired, isFalse, reason: product);
      expect(policy.handoverEvidenceRequired, isFalse, reason: product);
    }
  });

  test('the supported product matrix is evaluated from persisted policy', () {
    const products = [
      ['Standard', 'standard', false],
      ['Standard + Vanguard', 'standard', true],
      ['Business', 'business', false],
      ['Business + Vanguard', 'business', true],
      ['Health+', 'health_plus', false],
      ['Health+ + Vanguard', 'health_plus', true],
      ['Gift', 'gift', false],
      ['Gift + Vanguard', 'gift', true],
    ];

    for (final entry in products) {
      final policy = RiderCompletionPolicy.fromRaw({
        'serviceType': entry[1],
        'requiresVanguard': entry[2],
        'iris': {'verification': ordinaryVerification},
      });
      final protectedByVanguard = entry[2] as bool;
      expect(policy.pickupVerificationRequired, protectedByVanguard,
          reason: entry[0] as String);
      expect(policy.receiverVerificationRequired, protectedByVanguard,
          reason: entry[0] as String);
      expect(policy.handoverEvidenceRequired, protectedByVanguard,
          reason: entry[0] as String);
    }
  });

  test('Vanguard strengthens policy even when nested false values are present', () {
    final policy = RiderCompletionPolicy.fromRaw({
      'requiresVanguard': true,
      'iris': {'verification': ordinaryVerification},
    });
    expect(policy.pickupVerificationRequired, isTrue);
    expect(policy.receiverVerificationRequired, isTrue);
    expect(policy.handoverEvidenceRequired, isTrue);
  });

  test('unknown policy fails closed', () {
    final policy = RiderCompletionPolicy.fromRaw(const {});
    expect(policy.pickupVerificationRequired, isTrue);
    expect(policy.receiverVerificationRequired, isTrue);
    expect(policy.handoverEvidenceRequired, isTrue);
    expect(policy.authoritative, isFalse);
  });
}
