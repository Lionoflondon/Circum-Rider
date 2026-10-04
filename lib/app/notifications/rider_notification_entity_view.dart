import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../rider_jobs/rider_job_offer_screen.dart';
import '../rider_jobs/rider_offer_card.dart';
import '../stripe/rider_production_payment_api.dart';

class RiderNotificationTarget {
  const RiderNotificationTarget(this.collection, this.id,
      {this.isOffer = false});
  final bool isOffer;
  final String collection, id;
  static RiderNotificationTarget? fromDestination(Map<String, dynamic> data,
      {String category = ''}) {
    final route = '${data['route'] ?? category}'.toLowerCase();
    String value(List<String> keys) => keys
        .map((k) => '${data[k] ?? ''}'.trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final (collection, id) = switch (route) {
      'jobs' || 'job' || 'tracking' || 'delivery' || 'deliveries' => (
          'deliveryRequests',
          value(['deliveryId', 'requestId', 'bookingId', 'entityId'])
        ),
      'wallet' || 'earnings' || 'payout' => (
          'payoutRequests',
          value(['payoutRequestId', 'withdrawalId', 'requestId', 'entityId'])
        ),
      'account' || 'profile' => (
          'riderApplications',
          value(['applicationId', 'entityId'])
        ),
      'schedule' => (
          'deliveryRequests',
          value(['deliveryId', 'requestId', 'bookingId', 'entityId'])
        ),
      _ => ('', ''),
    };
    if (collection.isEmpty || id.isEmpty || id.contains('/')) return null;
    return RiderNotificationTarget(collection, id,
        isOffer: route == 'jobs' || route == 'job');
  }
}

bool riderOwnsNotificationEntity(Map<String, dynamic> data, String uid,
    {String collection = 'deliveryRequests', String? documentId}) {
  if (collection == 'riderApplications') return documentId == uid;
  if (collection == 'payoutRequests') return data['riderId'] == uid;
  final owners = [
    'riderId',
    'driverId',
    'assignedRider',
    'assignedRiderId',
    'assignedDriverId',
    'courierId'
  ]
      .map((key) => '${data[key] ?? ''}'.trim())
      .where((value) => value.isNotEmpty)
      .toList();
  return owners.isNotEmpty && owners.every((owner) => owner == uid);
}

class RiderNotificationEntityView extends StatelessWidget {
  const RiderNotificationEntityView({super.key, required this.target});
  final RiderNotificationTarget target;
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _fallback('Sign in to view this update.');
    if (target.isOffer)
      return RiderJobOfferScreen(initialDeliveryId: target.id);
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection(target.collection)
            .doc(target.id)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.hasError || (snapshot.hasData && !snapshot.data!.exists))
            return _fallback('This update is no longer available.');
          if (!snapshot.hasData)
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          final data = snapshot.data!.data()!;
          if (!riderOwnsNotificationEntity(data, uid,
              collection: target.collection, documentId: target.id))
            return _fallback('This update is no longer available.');
          final status =
              '${data['status'] ?? data['payoutStatus'] ?? data['approvalStatus'] ?? 'Pending'}';
          if (target.collection == 'deliveryRequests' &&
              !{'delivered', 'completed', 'cancelled', 'canceled', 'expired'}
                  .contains(status.toLowerCase())) {
            return RiderAcceptedJobScreen(
                offer:
                    RiderJobOffer.fromFirestore(docId: target.id, data: data));
          }
          return Scaffold(
              appBar: AppBar(title: const Text('Your update')),
              body: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            target.collection == 'payoutRequests'
                                ? 'Withdrawal'
                                : 'Delivery or application',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 12),
                        Text('Reference: ${target.id}'),
                        Text('Status: $status'),
                        if (data['amount'] is num)
                          Text(
                              'Amount: £${(data['amount'] as num).toStringAsFixed(2)}'),
                        if (target.collection == 'payoutRequests' &&
                            {'requested', 'pending'}
                                .contains(status.toLowerCase()))
                          RiderWithdrawalCancelButton(requestId: target.id)
                      ])));
        });
  }

  Widget _fallback(String message) => Scaffold(
      appBar: AppBar(title: const Text('Notification')),
      body: Center(child: Text(message)));
}

class RiderWithdrawalCancelButton extends StatefulWidget {
  const RiderWithdrawalCancelButton(
      {super.key, required this.requestId, this.cancel});
  final String requestId;
  final Future<void> Function(String)? cancel;
  @override
  State<RiderWithdrawalCancelButton> createState() =>
      RiderWithdrawalCancelButtonState();
}

class RiderWithdrawalCancelButtonState
    extends State<RiderWithdrawalCancelButton> {
  bool _busy = false;
  String? _error;
  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Cancel this withdrawal?'),
                content: Text(
                    'Request ${widget.requestId} will be cancelled if it is still pending.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep request')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Cancel withdrawal'))
                ]));
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _busy = false);
      return;
    }
    try {
      if (widget.cancel != null) {
        await widget.cancel!(widget.requestId);
      } else {
        await RiderProductionPaymentApi.payout(
            'cancelRiderWithdrawal', {'requestId': widget.requestId});
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'Cancellation could not be confirmed. Refresh this request before retrying.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        TextButton(
            onPressed: _busy ? null : _cancel,
            child: Text(_busy ? 'Cancelling…' : 'Cancel withdrawal')),
        if (_error != null) Text(_error!),
      ]);
}
