class RiderCompletionPolicy {
  final bool pickupVerificationRequired;
  final bool receiverVerificationRequired;
  final bool handoverEvidenceRequired;
  final bool authoritative;

  const RiderCompletionPolicy({
    required this.pickupVerificationRequired,
    required this.receiverVerificationRequired,
    required this.handoverEvidenceRequired,
    required this.authoritative,
  });

  static bool? _bool(dynamic value) {
    if (value is bool) return value;
    return null;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  factory RiderCompletionPolicy.fromRaw(Map<String, dynamic> raw) {
    final iris = _map(raw['iris'] is Map ? raw['iris'] : raw['irisDeliveryEstimate']);
    final verification = _map(iris['verification'] is Map
        ? iris['verification']
        : raw['completionPolicy']);
    final pickupExplicit = _bool(verification['pickupVerificationRequired']) ??
        _bool(raw['verificationRequired']) ??
        _bool(raw['requiresVerification']);
    final receiverExplicit = _bool(verification['recipientPinRequired']) ??
        _bool(raw['receiverPinRequired']) ??
        _bool(raw['pinRequired']) ??
        _bool(raw['secureHandoverRequired']);
    final evidenceExplicit = _bool(verification['handoverEvidenceRequired']) ??
        _bool(verification['photoEvidenceRequired']) ??
        _bool(raw['handoverEvidenceRequired']) ??
        _bool(raw['deliveryPhotoRequired']) ??
        _bool(raw['secureHandoverRequired']);
    final vanguardProtected = raw['requiresVanguard'] == true ||
        raw['vanguardEnabled'] == true ||
        raw['vanguardProtocolEnabled'] == true ||
        _map(raw['vanguardProtection'])['enabled'] == true ||
        _map(raw['vanguardProtocol'])['enabled'] == true;
    final explicitlyOrdinary = raw['vanguardProtocolEnabled'] == false ||
        raw['vanguardStatus'] == 'not_required' ||
        pickupExplicit == false &&
            receiverExplicit == false &&
            evidenceExplicit == false;
    final knownPolicy = pickupExplicit != null ||
        receiverExplicit != null ||
        evidenceExplicit != null ||
        vanguardProtected ||
        explicitlyOrdinary;

    return RiderCompletionPolicy(
      pickupVerificationRequired: vanguardProtected
          ? true
          : pickupExplicit ?? (!explicitlyOrdinary || !knownPolicy),
      receiverVerificationRequired: vanguardProtected
          ? true
          : receiverExplicit ?? !knownPolicy,
      handoverEvidenceRequired: vanguardProtected
          ? true
          : evidenceExplicit ?? !knownPolicy,
      authoritative: verification.isNotEmpty ||
          pickupExplicit != null ||
          receiverExplicit != null ||
          evidenceExplicit != null,
    );
  }
}
