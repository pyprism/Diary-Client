import 'package:diary_client/core/constants/app_constants.dart';
import 'package:diary_client/core/network/server_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_shared_preferences.dart';

void main() {
  group('ServerConfig.parseServerInput', () {
    test('handles domains, urls, ports, whitespace, and invalid input', () {
      expect(ServerConfig.parseServerInput(' example.com '), (
        domain: 'example.com',
        useHttps: true,
      ));
      expect(ServerConfig.parseServerInput('http://localhost:8000'), (
        domain: 'localhost:8000',
        useHttps: false,
      ));
      expect(ServerConfig.parseServerInput('https://api.example.com'), (
        domain: 'api.example.com',
        useHttps: true,
      ));
      expect(ServerConfig.parseServerInput(''), isNull);
      expect(ServerConfig.parseServerInput('not a url'), isNull);
    });
  });

  group('ServerConfig', () {
    test('builds baseUrl and endpoint with normalized slashes', () async {
      final prefs = await createTestSharedPreferences({
        AppConstants.keyDomain: 'api.example.com',
        AppConstants.keyUseHttps: true,
      });
      final config = ServerConfig(prefs);

      expect(config.serverInput, 'https://api.example.com');
      expect(config.baseUrl, 'https://api.example.com/api/v1/');
      expect(
        config.endpoint('/diaries/'),
        'https://api.example.com/api/v1/diaries/',
      );
      expect(config.endpoint(''), 'https://api.example.com/api/v1/');
    });

    test('saveFromInput stores parsed domain and scheme', () async {
      final prefs = await createTestSharedPreferences();
      final config = ServerConfig(prefs);

      await config.saveFromInput('http://localhost:9000');

      expect(config.domain, 'localhost:9000');
      expect(config.useHttps, isFalse);
    });

    test(
      'saveFromInput throws for invalid input and clear removes values',
      () async {
        final prefs = await createTestSharedPreferences();
        final config = ServerConfig(prefs);

        await expectLater(
          config.saveFromInput('not valid'),
          throwsA(isA<FormatException>()),
        );

        await config.save(domain: 'example.com', useHttps: true);
        await config.clear();

        expect(config.domain, isEmpty);
        expect(config.useHttps, isTrue);
        expect(config.isConfigured, isFalse);
      },
    );
  });
}
