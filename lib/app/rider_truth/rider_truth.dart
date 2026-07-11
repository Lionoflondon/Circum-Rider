class RiderRankSnapshot {
  const RiderRankSnapshot(
      {required this.rank, required this.trustPoints, this.overrideReason});

  final String rank;
  final int trustPoints;
  final String? overrideReason;

  static const ranks = ['Agent', 'Sentinel', 'Warden', 'Knight', 'Veteran'];
  static const thresholds = [0, 100, 300, 700, 1500];

  static RiderRankSnapshot? from(Map<String, dynamic> data) {
    final rawTrust = data['trustPoints'] ?? data['riderTrustPoints'];
    if (rawTrust is! num) return null;
    final trust = rawTrust.toInt();
    final calculated = rankForTrust(trust);
    final rawRank = '${data['riderRank'] ?? data['rank'] ?? ''}'.trim();
    final validRank = ranks
        .where((rank) => rank.toLowerCase() == rawRank.toLowerCase())
        .firstOrNull;
    final override = data['rankOverride'] == true ||
        '${data['rankSource'] ?? ''}'.toLowerCase() == 'manual';
    return RiderRankSnapshot(
      rank: override && validRank != null ? validRank : calculated,
      trustPoints: trust,
      overrideReason: override && validRank != null
          ? '${data['rankOverrideReason'] ?? 'Manual rank override'}'
          : null,
    );
  }

  static String rankForTrust(int trust) {
    var index = 0;
    for (var i = 0; i < thresholds.length; i++) {
      if (trust >= thresholds[i]) index = i;
    }
    return ranks[index];
  }
}

class RiderEarningsSummary {
  const RiderEarningsSummary(
      {required this.available,
      required this.pending,
      required this.delivery,
      required this.tips,
      required this.waiting,
      required this.adjustments});
  final double available;
  final double pending;
  final double delivery;
  final double tips;
  final double waiting;
  final double adjustments;

  static RiderEarningsSummary? from(Map<String, dynamic> wallet) {
    final available = wallet['availableBalance'] ?? wallet['accountBalance'];
    final pending = wallet['pendingBalance'] ?? wallet['pendingEarnings'];
    if (available is! num || pending is! num) return null;
    double amount(String key) =>
        wallet[key] is num ? (wallet[key] as num).toDouble() : 0;
    return RiderEarningsSummary(
      available: available.toDouble(),
      pending: pending.toDouble(),
      delivery: amount('deliveryEarningsTotal'),
      tips: amount('tipsTotal'),
      waiting: amount('waitingNoShowTotal'),
      adjustments: amount('adjustmentsTotal'),
    );
  }
}

class RiderVehicleSnapshot {
  const RiderVehicleSnapshot(
      {required this.type,
      required this.makeModel,
      required this.colour,
      required this.registration,
      required this.status,
      required this.primary,
      required this.registrationRequired});
  final String type;
  final String? makeModel;
  final String? colour;
  final String? registration;
  final String status;
  final bool primary;
  final bool registrationRequired;

  static RiderVehicleSnapshot from(Map<String, dynamic> value,
      {required bool primary}) {
    final type = '${value['type'] ?? value['vehicleType'] ?? ''}'.trim();
    final make = '${value['make'] ?? ''}'.trim();
    final model = '${value['model'] ?? ''}'.trim();
    final registration =
        '${value['registration'] ?? value['registrationPlate'] ?? value['plate'] ?? ''}'
            .trim();
    final bicycle =
        type.toLowerCase().contains('bicycle') || type.toLowerCase() == 'bike';
    final rawStatus = '${value['verificationStatus'] ?? value['status'] ?? ''}'
        .trim()
        .toLowerCase();
    final verified = value['verified'] == true ||
        rawStatus == 'verified' ||
        rawStatus == 'approved';
    return RiderVehicleSnapshot(
      type: type,
      makeModel:
          [make, model].where((v) => v.isNotEmpty).join(' ').trim().isEmpty
              ? null
              : [make, model].where((v) => v.isNotEmpty).join(' '),
      colour: '${value['colour'] ?? value['color'] ?? ''}'.trim().isEmpty
          ? null
          : '${value['colour'] ?? value['color']}'.trim(),
      registration: registration.isEmpty ? null : registration,
      status: verified
          ? 'VERIFIED'
          : rawStatus.isEmpty
              ? 'INCOMPLETE'
              : rawStatus.toUpperCase(),
      primary: primary,
      registrationRequired: !bicycle,
    );
  }
}
