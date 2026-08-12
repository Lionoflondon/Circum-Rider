import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../rider_design/rider_ui.dart';

class RiderRothReferralView extends StatefulWidget {
  const RiderRothReferralView({super.key});

  @override
  State<RiderRothReferralView> createState() => _RiderRothReferralViewState();
}

class _RiderRothReferralViewState extends State<RiderRothReferralView> {
  late Future<Map<String, dynamic>> _dashboard;

  @override
  void initState() {
    super.initState();
    _dashboard = _loadDashboard();
  }

  Future<Map<String, dynamic>> _loadDashboard() async {
    final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('getReferralDashboard')
        .call({'pageSize': 20});
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Referral link copied.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RiderPalette.background,
      appBar: AppBar(
        title: const Text('Roth Referral'),
        backgroundColor: RiderPalette.background,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboard,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Referral details are unavailable right now. Please try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: RiderPalette.muted),
                ),
              ),
            );
          }
          final data = snapshot.data ?? const <String, dynamic>{};
          final code = '${data['referralCode'] ?? ''}'.trim();
          final link = '${data['referralLink'] ?? ''}'.trim();
          final referrals = (data['referrals'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              RiderGlassSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invite through Roth',
                      style: TextStyle(
                        color: RiderPalette.paper,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your referral reward is issued by the verified referral engine as Roth after the qualifying activity.',
                      style: TextStyle(
                        color: RiderPalette.muted,
                        height: 1.45,
                      ),
                    ),
                    if (code.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text('Code: $code',
                          style: const TextStyle(
                              color: RiderPalette.paper,
                              fontWeight: FontWeight.w800)),
                    ],
                    if (link.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _copy(link),
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copy referral link'),
                        ),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 18),
                        child: Text('Referral code not available yet.',
                            style: TextStyle(color: RiderPalette.amber)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Referral history',
                  style: TextStyle(
                      color: RiderPalette.paper,
                      fontSize: 17,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              if (referrals.isEmpty)
                const RiderGlassSurface(
                  child: Text('No referrals yet.',
                      style: TextStyle(color: RiderPalette.muted)),
                )
              else
                for (final referral in referrals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RiderGlassSurface(
                      child: Row(
                        children: [
                          const Icon(Icons.group_add_outlined,
                              color: RiderPalette.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${referral['status'] ?? 'invited'}',
                              style: const TextStyle(
                                color: RiderPalette.paper,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${referral['rewardAmount'] ?? 0} ROTH',
                            style: const TextStyle(
                              color: RiderPalette.green,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
