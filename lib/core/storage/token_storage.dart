import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  final SharedPreferences _prefs;

  const TokenStorage(this._prefs);

  Future<String?> read({required String key}) async => _prefs.getString(key);

  Future<void> write({required String key, required String value}) async {
    await _prefs.setString(key, value);
  }

  Future<void> delete({required String key}) async {
    await _prefs.remove(key);
  }

  Future<void> deleteAll(Iterable<String> keys) async {
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }
}
