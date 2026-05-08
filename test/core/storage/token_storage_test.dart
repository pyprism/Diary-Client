import 'package:diary_client/core/storage/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_shared_preferences.dart';

void main() {
  group('TokenStorage', () {
    test('reads and writes keys', () async {
      final prefs = await createTestSharedPreferences();
      final storage = TokenStorage(prefs);

      expect(await storage.read(key: 'access'), isNull);

      await storage.write(key: 'access', value: 'abc');

      expect(await storage.read(key: 'access'), 'abc');
    });

    test('deletes one or many keys', () async {
      final prefs = await createTestSharedPreferences({
        'access': 'abc',
        'refresh': 'xyz',
        'other': 'keep',
      });
      final storage = TokenStorage(prefs);

      await storage.delete(key: 'access');
      await storage.deleteAll(['refresh']);

      expect(await storage.read(key: 'access'), isNull);
      expect(await storage.read(key: 'refresh'), isNull);
      expect(await storage.read(key: 'other'), 'keep');
    });
  });
}
