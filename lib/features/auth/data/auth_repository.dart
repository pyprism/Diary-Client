import 'dart:convert';

import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/server_config.dart';
import '../../../../core/storage/token_storage.dart';
import '../domain/models/user_profile.dart';

class AuthRepository {
  final DioClient _client;
  final ServerConfig _config;
  final TokenStorage _storage;

  AuthRepository(this._client, this._config, this._storage);

  Future<void> login(String email, String password) async {
    if (!_config.isConfigured) {
      throw const AppException('Server is not configured. Set a domain first.');
    }
    try {
      final res = await _client.dio.post(
        _config.endpoint('auth/login'),
        data: {'email': email, 'password': password},
      );
      await _storage.write(
        key: AppConstants.keyAccessToken,
        value: res.data['access'],
      );
      await _storage.write(
        key: AppConstants.keyRefreshToken,
        value: res.data['refresh'],
      );
    } on DioException catch (e) {
      throw _asAppException(e, const AuthException('Login failed'));
    }
  }

  Future<void> register(String email, String password) async {
    if (!_config.isConfigured) {
      throw const AppException('Server is not configured. Set a domain first.');
    }
    try {
      await _client.dio.post(
        _config.endpoint('auth/register'),
        data: {'email': email, 'password': password},
      );
    } on DioException catch (e) {
      throw _asAppException(e, const AppException('Registration failed'));
    }
  }

  AppException _asAppException(DioException e, AppException fallback) {
    final err = e.error;
    if (err is AppException) return err;
    if (err is Exception) {
      return AppException(err.toString(), statusCode: e.response?.statusCode);
    }
    if (err is String && err.isNotEmpty) {
      return AppException(err, statusCode: e.response?.statusCode);
    }

    final detail = e.response?.data;
    if (detail is Map && detail['detail'] != null) {
      return AppException(
        detail['detail'].toString(),
        statusCode: e.response?.statusCode,
      );
    }

    return fallback;
  }

  Future<UserProfile?> getProfile() async {
    if (!_config.isConfigured) return null;
    try {
      final res = await _client.dio.get(_config.endpoint('auth/me'));
      return UserProfile.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<UserProfile> updateWebBaseUrl(String webBaseUrl) async {
    try {
      final res = await _client.dio.patch(
        _config.endpoint('auth/me'),
        data: {'web_base_url': webBaseUrl},
      );
      return UserProfile.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _asAppException(e, const AppException('Failed to update settings'));
    }
  }

  Future<bool> get isLoggedIn async {
    final accessToken = await _storage.read(key: AppConstants.keyAccessToken);
    if (accessToken != null &&
        accessToken.isNotEmpty &&
        !_isJwtExpired(accessToken)) {
      return true;
    }

    final refreshToken = await _storage.read(key: AppConstants.keyRefreshToken);
    return refreshToken != null &&
        refreshToken.isNotEmpty &&
        !_isJwtExpired(refreshToken);
  }

  Future<void> logout() async {
    final refreshToken = await _storage.read(key: AppConstants.keyRefreshToken);
    if (refreshToken != null &&
        refreshToken.isNotEmpty &&
        _config.isConfigured) {
      try {
        await _client.dio.post(
          _config.endpoint('auth/logout'),
          data: {'refresh': refreshToken},
        );
      } catch (_) {
        // Best-effort: local tokens are cleared below regardless of server outcome.
      }
    }

    await _storage.deleteAll([
      AppConstants.keyAccessToken,
      AppConstants.keyRefreshToken,
    ]);
  }

  bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map<String, dynamic>) return false;
      final exp = payload['exp'];
      if (exp is! int) return false;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return !expiry.isAfter(DateTime.now().add(const Duration(seconds: 30)));
    } catch (_) {
      return false;
    }
  }
}
