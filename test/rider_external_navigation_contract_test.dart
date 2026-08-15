import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider legal links use leave-app confirmation helper', () {
    final profile =
        File('lib/app/rider_shell/rider_profile_view.dart').readAsStringSync();
    final helper =
        File('lib/app/platform/rider_external_navigation.dart').readAsStringSync();

    expect(profile, contains('openRiderLegalLink('));
    expect(
      profile,
      isNot(contains("launchUrl(Uri.parse('https://circumuk.com/terms'))")),
    );
    expect(
      profile,
      isNot(contains("launchUrl(Uri.parse('https://circumuk.com/privacy'))")),
    );
    expect(helper, contains("You're leaving CIRCUM"));
    expect(helper, contains('This link will open outside the CIRCUM app.'));
    expect(helper, contains("uri.host == 'circumuk.com'"));
    expect(helper, contains("uri.path == '/terms' || uri.path == '/privacy'"));
  });

  test('Rider app buttons do not keep empty enabled callbacks', () {
    final files = Directory('lib/app')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final emptyCallback = RegExp(
      r'(onPressed|onTap)\s*:\s*(?:\([^)]*\)|[A-Za-z0-9_]+)?\s*(?:async\s*)?'
      r'(?:=>\s*null|=>\s*\{\}|=>\s*Future\.value\(\)|\{\s*\})',
      multiLine: true,
    );
    final offenders = <String>[];

    for (final file in files) {
      final source = file
          .readAsStringSync()
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      for (final match in emptyCallback.allMatches(source)) {
        offenders.add('${file.path}: ${match.group(0)}');
      }
    }

    expect(offenders, isEmpty);
  });
}
