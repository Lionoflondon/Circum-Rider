import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../communication/rider_conversation_view.dart';

class RiderSafetyView extends StatelessWidget {
  const RiderSafetyView({super.key, required this.deliveryId, this.position});
  final String deliveryId;
  final Position? position;

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Safety and support')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text(
            'If you are in immediate danger, call emergency services. Circum chat is not an emergency response service.'),
        const SizedBox(height: 16),
        ListTile(
            leading: const Icon(Icons.emergency),
            title: const Text('Call 999'),
            subtitle: const Text('UK emergency services'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                          title: const Text('Call emergency services?'),
                          content: const Text(
                              'Your phone will open the dialler for 999.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Open dialler'))
                          ]));
              if (confirmed != true) return;
              try {
                if (!await launchUrl(Uri.parse('tel:999')))
                  throw StateError('dialler unavailable');
              } catch (_) {
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Open your phone dialler and call 999.')));
              }
            }),
        ListTile(
            leading: const Icon(Icons.share_location),
            title: const Text('Share current location'),
            subtitle: Text(position == null
                ? 'Waiting for a fresh GPS location'
                : 'Choose who receives this location. It does not update live.'),
            enabled: position != null &&
                DateTime.now().difference(position!.timestamp).abs() <
                    const Duration(minutes: 3),
            onTap: () async {
              final fix = position;
              if (fix == null) return;
              if (DateTime.now().difference(fix.timestamp).abs() >=
                  const Duration(minutes: 3)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content:
                        Text('Wait for a fresh GPS location before sharing.')));
                return;
              }
              final box = context.findRenderObject() as RenderBox?;
              try {
                await Share.share(
                    'My location during a Circum delivery: https://maps.google.com/?q=${fix.latitude},${fix.longitude}\nRecorded ${fix.timestamp.toLocal()}. This is a single location, not live tracking.',
                    sharePositionOrigin: box == null
                        ? null
                        : box.localToGlobal(Offset.zero) & box.size);
              } catch (_) {
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Location could not be shared. Please try again.')));
              }
            }),
        ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Contact Circum support'),
            subtitle: const Text(
                'Include the delivery reference when reporting a safety issue.'),
            onTap: () {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => RiderConversationView(
                          chatId: 'admin_rider_${uid}_general',
                          title: 'Circum Support',
                          subtitle: 'Delivery $deliveryId',
                          initialDraft:
                              'Safety issue with delivery $deliveryId: ')));
            }),
      ]));
}
