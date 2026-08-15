import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

bool isApprovedRiderExternalUri(Uri uri) =>
    uri.scheme == 'https' &&
    uri.host == 'circumuk.com' &&
    (uri.path == '/terms' || uri.path == '/privacy');

Future<void> openRiderLegalLink(
  BuildContext context, {
  required Uri uri,
}) async {
  if (!isApprovedRiderExternalUri(uri)) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("You're leaving CIRCUM"),
      content: const Text('This link will open outside the CIRCUM app.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
