import 'package:cloud_functions/cloud_functions.dart';

class RiderRothOnboardingResult {
  const RiderRothOnboardingResult({
    required this.walletCreated,
    required this.walletExisted,
  });

  final bool walletCreated;
  final bool walletExisted;
}

class RiderRothOnboarding {
  const RiderRothOnboarding({FirebaseFunctions? functions})
      : _functions = functions;

  final FirebaseFunctions? _functions;

  static const walletCollection = 'riderRothWallets';
  static const ledgerCollection = 'riderRothLedger';
  static const completionField = 'rothOnboardingComplete';
  static const statusField = 'rothOnboardingStatus';

  FirebaseFunctions get _backend => _functions ?? FirebaseFunctions.instance;

  Future<RiderRothOnboardingResult> ensureWalletForRider({
    required String riderId,
    String? email,
  }) async {
    final result = await _backend.httpsCallable('ensureRiderRothWallet').call({
      'riderId': riderId,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
    });
    final data = Map<String, dynamic>.from(result.data as Map);

    return RiderRothOnboardingResult(
      walletCreated: data['walletCreated'] == true,
      walletExisted: data['walletExisted'] == true,
    );
  }

  static bool needsOnboarding(Map<String, dynamic> rider) {
    final complete = rider[completionField] == true;
    final status = '${rider[statusField] ?? ''}'.trim().toLowerCase();
    return !complete &&
        !{'connected', 'wallet_created', 'complete', 'completed'}
            .contains(status);
  }

  static bool isCashLedgerCollection(String collectionPath) {
    final value = collectionPath.toLowerCase();
    return value.contains('riderearnings') ||
        value.contains('payout') ||
        value.contains('stripe');
  }
}
