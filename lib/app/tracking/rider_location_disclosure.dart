import 'package:flutter/material.dart';

typedef RiderLocationDisclosure = Future<bool> Function();

class RiderLocationDisclosureDialog {
  const RiderLocationDisclosureDialog._();

  static Future<bool> show(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location tracking'),
        content: const Text(
          'Circum Rider collects location data to enable delivery tracking, '
          'route progress and live delivery location even when the app is '
          'closed or not in use.\n\nYour location is used while performing '
          'delivery-related Rider functions so CIRCUM can track delivery '
          'progress and provide location updates required for the delivery service.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return accepted == true;
  }
}
