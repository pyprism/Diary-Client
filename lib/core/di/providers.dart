import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/server_config.dart';
import '../network/dio_client.dart';
import '../network/connectivity_service.dart';
import '../storage/app_database.dart';
import '../storage/token_storage.dart';

// Shared Preferences - initialized before app starts
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in main');
});

// Token Storage
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(ref.watch(sharedPrefsProvider));
});

// Server Config
final serverConfigProvider = Provider<ServerConfig>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return ServerConfig(prefs);
});

// Dio Client
final dioClientProvider = Provider<DioClient>((ref) {
  final config = ref.watch(serverConfigProvider);
  final storage = ref.watch(tokenStorageProvider);
  return DioClient(config, storage);
});

// Database
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// Connectivity
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

final isOnlineProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).onlineStream;
});
