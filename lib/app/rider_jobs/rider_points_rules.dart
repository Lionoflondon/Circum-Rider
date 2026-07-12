enum RiderJobCategory {
  standard,
  marketplace,
  business,
  vanguard,
  heavyDuty,
  gift,
  scheduled,
  healthPlus,
}

class RiderPointsResult {
  final RiderJobCategory category;
  final int points;
  final String label;
  final bool usedFallback;

  const RiderPointsResult({
    required this.category,
    required this.points,
    required this.label,
    required this.usedFallback,
  });
}

class RiderPointsRules {
  static const Map<RiderJobCategory, int> points = {
    RiderJobCategory.standard: 1,
    RiderJobCategory.marketplace: 2,
    RiderJobCategory.business: 3,
    RiderJobCategory.vanguard: 4,
    RiderJobCategory.heavyDuty: 4,
    RiderJobCategory.gift: 5,
    RiderJobCategory.scheduled: 5,
    RiderJobCategory.healthPlus: 6,
  };

  static const List<RiderJobCategory> priority = [
    RiderJobCategory.healthPlus,
    RiderJobCategory.gift,
    RiderJobCategory.scheduled,
    RiderJobCategory.vanguard,
    RiderJobCategory.heavyDuty,
    RiderJobCategory.business,
    RiderJobCategory.marketplace,
    RiderJobCategory.standard,
  ];

  static RiderPointsResult resolve(Map<String, dynamic> job) {
    final categories = <RiderJobCategory>{};

    void addWhen(dynamic value, RiderJobCategory category) {
      if (_isTruthy(value)) categories.add(category);
    }

    addWhen(job['isHealthPlus'] ?? job['healthPlus'] ?? job['health_plus'],
        RiderJobCategory.healthPlus);
    addWhen(job['isGift'] ?? job['gift'] ?? job['giftDelivery'],
        RiderJobCategory.gift);
    addWhen(job['isScheduled'] ?? job['scheduled'] ?? job['scheduledDelivery'],
        RiderJobCategory.scheduled);
    addWhen(
        job['requiresVanguard'] ?? job['vanguard'] ?? job['vanguardIncluded'],
        RiderJobCategory.vanguard);
    addWhen(job['isBusiness'] ?? job['business'] ?? job['businessDelivery'],
        RiderJobCategory.business);
    addWhen(job['isMarketplace'] ?? job['marketplace'],
        RiderJobCategory.marketplace);
    addWhen(job['isHeavyDuty'] ?? job['heavyDuty'] ?? job['heavy'],
        RiderJobCategory.heavyDuty);

    final rawCategory =
        '${job['category'] ?? job['deliveryType'] ?? job['serviceType'] ?? ''}'
            .toLowerCase();
    if (rawCategory.contains('health')) {
      categories.add(RiderJobCategory.healthPlus);
    } else if (rawCategory.contains('gift')) {
      categories.add(RiderJobCategory.gift);
    } else if (rawCategory.contains('scheduled')) {
      categories.add(RiderJobCategory.scheduled);
    } else if (rawCategory.contains('vanguard')) {
      categories.add(RiderJobCategory.vanguard);
    } else if (rawCategory.contains('business')) {
      categories.add(RiderJobCategory.business);
    } else if (rawCategory.contains('marketplace')) {
      categories.add(RiderJobCategory.marketplace);
    } else if (rawCategory.contains('heavy')) {
      categories.add(RiderJobCategory.heavyDuty);
    }

    final category = priority.firstWhere(
      categories.contains,
      orElse: () => RiderJobCategory.standard,
    );

    return RiderPointsResult(
      category: category,
      points: points[category]!,
      label: labelFor(category),
      usedFallback: categories.isEmpty,
    );
  }

  static String labelFor(RiderJobCategory category) {
    switch (category) {
      case RiderJobCategory.healthPlus:
        return 'Health+';
      case RiderJobCategory.gift:
        return 'Gift';
      case RiderJobCategory.scheduled:
        return 'Scheduled';
      case RiderJobCategory.vanguard:
        return 'Vanguard';
      case RiderJobCategory.heavyDuty:
        return 'Heavy Duty';
      case RiderJobCategory.business:
        return 'Business';
      case RiderJobCategory.marketplace:
        return 'Marketplace';
      case RiderJobCategory.standard:
        return 'Standard';
    }
  }

  static bool _isTruthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == 'yes' ||
          normalized == 'included' ||
          normalized == 'required';
    }
    return false;
  }
}
