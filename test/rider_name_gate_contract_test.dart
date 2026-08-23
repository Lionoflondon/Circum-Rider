import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the standalone Add Your Name page is removed from Rider runtime', () {
    final runtimeFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final runtime =
        runtimeFiles.map((file) => file.readAsStringSync()).join('\n');
    final app = File('lib/app.dart').readAsStringSync();
    final status = File('lib/app/rider_account/rider_account_status_view.dart')
        .readAsStringSync();

    expect(File('lib/app/authentication/view/add_details.dart').existsSync(),
        isFalse);
    expect(File('lib/app/authentication/view/index_page.dart').existsSync(),
        isFalse);
    expect(runtime, isNot(contains('Add Your Name')));
    expect(runtime, isNot(contains('Phil Knight')));
    expect(runtime, isNot(contains('AddDetailsView')));
    expect(app, contains('RiderApplicationCentre'));
    expect(status, contains('RiderApplicationCentre'));
  });
}
