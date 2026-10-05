import 'package:flutter/material.dart';

import 'rider_offer_card.dart';

/// Counts only current, authorized offers; this is not a demand forecast.
Map<String, int> riderDemandAreas(List<RiderJobOffer> offers, {DateTime? now}) {
  final time = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final seen = <String>{};
  final counts = <String, int>{};
  for (final offer in offers) {
    final expiry = offer.raw['offerExpiresAt'];
    final area = offer.pickupArea.trim();
    if (offer.raw['projectionVersion'] != 2 ||
        expiry is! num ||
        !expiry.isFinite ||
        expiry <= time ||
        offer.id.isEmpty ||
        area.isEmpty ||
        area == 'Location pending' ||
        !seen.add(offer.id)) continue;
    counts.update(area, (count) => count + 1, ifAbsent: () => 1);
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount == 0 ? a.key.compareTo(b.key) : byCount;
    });
  return Map.fromEntries(sorted.take(3));
}

class RiderDemandAreas extends StatelessWidget {
  const RiderDemandAreas({super.key, required this.offers});
  final List<RiderJobOffer> offers;

  @override
  Widget build(BuildContext context) {
    final areas = riderDemandAreas(offers);
    if (areas.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: 'Available pickup areas based on current offers',
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(spacing: 8, runSpacing: 4, children: [
          for (final area in areas.entries)
            Chip(
              avatar:
                  const Icon(Icons.local_fire_department_outlined, size: 18),
              label: Text('${area.key}: ${area.value} available'),
            ),
        ]),
      ),
    );
  }
}
