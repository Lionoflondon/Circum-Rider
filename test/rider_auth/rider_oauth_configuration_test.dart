import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rider Android release certificate has a Google OAuth client', () {
    final config = jsonDecode(
      File('android/app/google-services.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final clients = config['client'] as List<dynamic>;
    final rider = clients.cast<Map<String, dynamic>>().singleWhere(
          (client) =>
              (client['client_info']
                      as Map<String, dynamic>)['android_client_info']
                  ['package_name'] ==
              'com.circum.rider',
        );
    final oauthClients = rider['oauth_client'] as List<dynamic>;

    expect(
      oauthClients.cast<Map<String, dynamic>>().any((client) {
        final android = client['android_info'] as Map<String, dynamic>?;
        return android?['package_name'] == 'com.circum.rider' &&
            android?['certificate_hash'] ==
                '962e01f3b1aadf96c12362cb4a7f83429df5088e';
      }),
      isTrue,
    );
  });
}
