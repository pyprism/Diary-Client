import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ServerConfig {
  final SharedPreferences _prefs;
  static final RegExp _edgeSlashes = RegExp(r'^/+|/+$');

  ServerConfig(this._prefs);

  String get domain => _prefs.getString(AppConstants.keyDomain) ?? '';
  bool get useHttps => _prefs.getBool(AppConstants.keyUseHttps) ?? true;

  // Full server URL representation used to prefill text fields.
  String get serverInput =>
      isConfigured ? '${useHttps ? 'https' : 'http'}://$domain' : '';

  String get baseUrl {
    final scheme = useHttps ? 'https' : 'http';
    final apiPrefix = AppConstants.apiPrefix.replaceAll(_edgeSlashes, '');
    return '$scheme://$domain/$apiPrefix/';
  }

  String endpoint(String path) {
    final normalizedPath = path.trim().replaceAll(_edgeSlashes, '');
    if (normalizedPath.isEmpty) return baseUrl;
    return '$baseUrl$normalizedPath/';
  }

  bool get isConfigured => domain.isNotEmpty;

  static ({String domain, bool useHttps})? parseServerInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (RegExp(r'\s').hasMatch(trimmed)) return null;

    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty || uri.host.contains('%')) return null;

    final domain = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    final useHttps = uri.scheme.toLowerCase() != 'http';
    return (domain: domain, useHttps: useHttps);
  }

  Future<void> saveFromInput(String input) async {
    final parsed = parseServerInput(input);
    if (parsed == null) {
      throw const FormatException('Invalid server URL');
    }
    await save(domain: parsed.domain, useHttps: parsed.useHttps);
  }

  Future<void> save({required String domain, required bool useHttps}) async {
    await _prefs.setString(AppConstants.keyDomain, domain);
    await _prefs.setBool(AppConstants.keyUseHttps, useHttps);
  }

  Future<void> clear() async {
    await _prefs.remove(AppConstants.keyDomain);
    await _prefs.remove(AppConstants.keyUseHttps);
  }
}
