class AppConstants {
  static const String apiVersion = 'v1';
  static const String apiPrefix = 'api/$apiVersion';

  // SharedPreferences keys
  static const String keyDomain = 'server_domain';
  static const String keyUseHttps = 'use_https';

  // Secure storage keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';

  // Pagination
  static const int defaultPageSize = 20;

  // Analysis polling
  static const int analysisMaxRetries = 20;
  static const Duration analysisPollInterval = Duration(seconds: 10);

  // Share expiry options (in seconds)
  static const List<int> shareExpiryOptions = [3600, 86400, 604800, 2592000];
  static const List<String> shareExpiryLabels = [
    '1 Hour',
    '24 Hours',
    '1 Week',
    '30 Days'
  ];
}
