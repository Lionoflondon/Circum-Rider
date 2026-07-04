// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:flutter/material.dart';

import 'rider_points_rules.dart';

class RiderJobOffer {
  final String id;
  final String requestId;
  final String pickupArea;
  final String dropoffArea;
  final String pickupAddress;
  final String dropoffAddress;
  final double earnings;
  final String currency;
  final String distanceText;
  final String timeText;
  final String parcelGuidance;
  final String minimumVehicle;
  final String weightText;
  final String pickupTiming;
  final List<String> warningChips;
  final Map<String, dynamic> raw;

  const RiderJobOffer({
    required this.id,
    required this.requestId,
    required this.pickupArea,
    required this.dropoffArea,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.earnings,
    required this.currency,
    required this.distanceText,
    required this.timeText,
    required this.parcelGuidance,
    required this.minimumVehicle,
    required this.weightText,
    required this.pickupTiming,
    required this.warningChips,
    required this.raw,
  });

  factory RiderJobOffer.fromFirestore({
    required String docId,
    required Map<String, dynamic> data,
  }) {
    final pickupDetails = data['pickupDetails'] ?? data['pickup'];
    final dropoffDetails = data['dropoffDetails'] ?? data['dropoff'];
    final pickup = _areaSummary(pickupDetails);
    final dropoff = _areaSummary(dropoffDetails);
    final requestId = '${data['requestId'] ?? data['code'] ?? docId}'.trim();
    final price =
        (data['riderEarning'] ?? data['riderPay'] ?? data['price'] ?? 0);
    final distance = data['distanceText'] ??
        data['estimatedDistanceText'] ??
        data['distance'];
    final duration = data['durationText'] ??
        data['estimatedDurationText'] ??
        data['duration'];
    final item = data['itemName'] ??
        data['itemDescription'] ??
        data['parcelDescription'] ??
        data['packageType'] ??
        'Parcel';

    return RiderJobOffer(
      id: docId,
      requestId: requestId.isEmpty ? docId : requestId,
      pickupArea: pickup,
      dropoffArea: dropoff,
      pickupAddress: _fullAddress(pickupDetails),
      dropoffAddress: _fullAddress(dropoffDetails),
      earnings: price is num ? price.toDouble() : 0,
      currency: '${data['currency'] ?? 'GBP'}',
      distanceText: distance == null || '$distance'.trim().isEmpty
          ? 'Distance pending'
          : '$distance',
      timeText: duration == null || '$duration'.trim().isEmpty
          ? 'ETA pending'
          : '$duration',
      parcelGuidance: '$item',
      minimumVehicle:
          '${data['minimumVehicle'] ?? data['recommendedVehicle'] ?? data['vehicleType'] ?? 'Bike'}',
      weightText: _weightText(data),
      pickupTiming: _pickupTiming(data),
      warningChips: _warningChips(data),
      raw: data,
    );
  }

  RiderPointsResult get points => RiderPointsRules.resolve(raw);

  static String _areaSummary(dynamic value) {
    if (value is Map) {
      final candidates = [
        value['area'],
        value['city'],
        value['postcode'],
      ];
      for (final candidate in candidates) {
        final text = '$candidate'.trim();
        if (candidate != null && text.isNotEmpty && text != 'null') {
          return text;
        }
      }
    }
    final text = '$value'.trim();
    if (text.isNotEmpty && text != 'null') return text;
    return 'Location pending';
  }

  static String _fullAddress(dynamic value) {
    if (value is Map) {
      final candidates = [
        value['formattedAddress'],
        value['address'],
        [
          value['addressLine1'],
          value['addressLine2'],
          value['city'],
          value['postcode'],
        ].where((part) {
          final text = '$part'.trim();
          return part != null && text.isNotEmpty && text != 'null';
        }).join(', '),
      ];
      for (final candidate in candidates) {
        final text = '$candidate'.trim();
        if (candidate != null && text.isNotEmpty && text != 'null') {
          return text;
        }
      }
    }
    final text = '$value'.trim();
    if (text.isNotEmpty && text != 'null') return text;
    return 'Address pending';
  }

  static List<String> _warningChips(Map<String, dynamic> data) {
    final chips = <String>[];
    void addIf(dynamic value, String label) {
      if (value == true || '$value'.toLowerCase() == 'true') chips.add(label);
    }

    addIf(data['requiresVanguard'] ?? data['vanguardIncluded'], 'Vanguard');
    addIf(data['isHealthPlus'] ?? data['healthPlus'], 'Health+');
    addIf(data['isGift'] ?? data['giftDelivery'], 'Gift');
    addIf(data['isBusiness'] ?? data['businessDelivery'], 'Business');
    addIf(data['isHeavyDuty'] ?? data['heavyDuty'] ?? data['heavy'], 'Heavy');
    addIf(data['isScheduled'] ?? data['scheduled'], 'Scheduled');
    if (chips.isEmpty) chips.add('Standard');
    return chips;
  }

  static String _weightText(Map<String, dynamic> data) {
    final value = data['weightKg'] ??
        data['finalPricingWeightKg'] ??
        data['irisEstimatedWeightKg'] ??
        data['estimatedWeightKg'];
    if (value is num) return '${value.toStringAsFixed(value < 1 ? 1 : 0)}kg';
    final text = '$value'.trim();
    if (value != null && text.isNotEmpty && text != 'null') return text;
    return 'Weight pending';
  }

  static String _pickupTiming(Map<String, dynamic> data) {
    final scheduled = data['scheduledTime'] ??
        data['pickupWindow'] ??
        data['pickupTiming'] ??
        data['scheduledAt'];
    final text = '$scheduled'.trim();
    if (scheduled != null && text.isNotEmpty && text != 'null') return text;
    return 'ASAP';
  }
}

class RiderOfferCard extends StatelessWidget {
  final RiderJobOffer offer;
  final String riderRank;
  final bool accepting;
  final VoidCallback onAccept;

  const RiderOfferCard({
    super.key,
    required this.offer,
    required this.riderRank,
    required this.accepting,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final points = offer.points;
    final chips = _orderedChips(points.label);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1020).withOpacity(0.78),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.22),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _money(offer.earnings, offer.currency),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Estimated earnings',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.62),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _RankTrustColumn(
                            rank: riderRank,
                            trustPoints: points.points,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: chips
                            .map((chip) => _Chip(
                                  label: chip,
                                  highlighted: chip == points.label,
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 18),
                      _RouteSummary(
                        pickup: offer.pickupArea,
                        dropoff: offer.dropoffArea,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoTile(
                              icon: Icons.route_rounded,
                              label: offer.distanceText,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoTile(
                              icon: Icons.schedule_rounded,
                              label: offer.timeText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ParcelGuidance(text: offer.parcelGuidance),
                      const SizedBox(height: 10),
                      _MetadataRow(
                        vehicle: offer.minimumVehicle,
                        weight: offer.weightText,
                        timing: offer.pickupTiming,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: accepting ? null : onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    disabledBackgroundColor:
                        const Color(0xFF3B82F6).withOpacity(0.42),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: accepting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Accept Delivery',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _orderedChips(String categoryLabel) {
    final source = <String>{
      ...offer.warningChips,
      '${offer.minimumVehicle} minimum',
      categoryLabel,
    };
    final preferred = [
      'Health+',
      'Gift',
      'Vanguard',
      '${offer.minimumVehicle} minimum',
      'Scheduled',
      'Business',
      'Marketplace',
      'Heavy',
      'Heavy Duty',
      'Standard',
    ];
    final ordered = [
      ...preferred.where(source.contains),
      ...source.where((chip) => !preferred.contains(chip)),
    ];
    return ordered.take(5).toList();
  }

  static String _money(double value, String currency) {
    final symbol = currency.toUpperCase() == 'GBP' ? '£' : '$currency ';
    return '$symbol${value.toStringAsFixed(2)}';
  }
}

class _RankTrustColumn extends StatelessWidget {
  final String rank;
  final int trustPoints;

  const _RankTrustColumn({required this.rank, required this.trustPoints});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF38BDF8).withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF60A5FA).withOpacity(0.38)),
      ),
      child: Column(
        children: [
          Text(rank,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text('+$trustPoints Trust',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.74),
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool highlighted;

  const _Chip({required this.label, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xFF2563EB).withOpacity(0.28)
            : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF60A5FA).withOpacity(0.48)
              : Colors.white.withOpacity(0.12),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted ? Colors.white : Colors.white.withOpacity(0.76),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  final String pickup;
  final String dropoff;

  const _RouteSummary({required this.pickup, required this.dropoff});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$pickup → $dropoff',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF60A5FA), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ParcelGuidance extends StatelessWidget {
  final String text;

  const _ParcelGuidance({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF07090F).withOpacity(0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined,
              color: Color(0xFF60A5FA), size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  final String vehicle;
  final String weight;
  final String timing;

  const _MetadataRow({
    required this.vehicle,
    required this.weight,
    required this.timing,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetaChip(label: 'Vehicle: $vehicle'),
        _MetaChip(label: 'Weight: $weight'),
        _MetaChip(label: 'Pickup: $timing'),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.68),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
