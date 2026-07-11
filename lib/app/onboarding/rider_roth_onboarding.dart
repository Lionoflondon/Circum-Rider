import 'package:cloud_firestore/cloud_firestore.dart';

class RiderRothOnboardingResult {
  const RiderRothOnboardingResult({
    required this.walletCreated,
    required this.walletExisted,
  });

  final bool walletCreated;
  final bool walletExisted;
}

class RiderRothOnboarding {
  const RiderRothOnboarding({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  static const walletCollection = 'riderRothWallets';
  static const ledgerCollection = 'riderRothLedger';
  static const auditCollection = 'riderOnboardingEvents';
  static const completionField = 'rothOnboardingComplete';
  static const statusField = 'rothOnboardingStatus';

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<RiderRothOnboardingResult> ensureWalletForRider({
    required String riderId,
    String? email,
  }) async {
    final riderRef = _db.collection('riders').doc(riderId);
    final walletRef = _db.collection(walletCollection).doc(riderId);
    var created = false;
    var existed = false;

    await _db.runTransaction((transaction) async {
      final wallet = await transaction.get(walletRef);
      final timestamp = FieldValue.serverTimestamp();
      if (wallet.exists) {
        existed = true;
        transaction.set(
            riderRef,
            {
              completionField: true,
              statusField: 'connected',
              'rothWalletId': walletRef.id,
              'rothWalletConnectedAt': timestamp,
              'updatedAt': timestamp,
            },
            SetOptions(merge: true));
      } else {
        created = true;
        transaction.set(walletRef, {
          'riderId': riderId,
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          'currency': 'ROTH',
          'balance': 0,
          'available': 0,
          'pending': 0,
          'status': 'active',
          'createdAt': timestamp,
          'updatedAt': timestamp,
          'source': 'rider_onboarding',
        });
        transaction.set(
            riderRef,
            {
              completionField: true,
              statusField: 'wallet_created',
              'rothWalletId': walletRef.id,
              'rothWalletConnectedAt': timestamp,
              'updatedAt': timestamp,
            },
            SetOptions(merge: true));
      }
    });

    await _db.collection(auditCollection).add({
      'riderId': riderId,
      'eventType': created ? 'roth_wallet_created' : 'roth_wallet_connected',
      'walletId': riderId,
      'timestamp': FieldValue.serverTimestamp(),
      'statusAfterEvent': created ? 'wallet_created' : 'connected',
    });

    return RiderRothOnboardingResult(
      walletCreated: created,
      walletExisted: existed,
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
