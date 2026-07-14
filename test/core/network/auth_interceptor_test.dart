import 'dart:convert';
import 'dart:typed_data';

import 'package:diary_client/core/constants/app_constants.dart';
import 'package:diary_client/core/network/auth_interceptor.dart';
import 'package:diary_client/core/network/server_config.dart';
import 'package:diary_client/core/storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_shared_preferences.dart';

/// Fake transport that counts /auth/token/refresh hits and answers every
/// other request with an empty 200, so the interceptor's retry-after-refresh
/// step has somewhere to land.
class _CountingRefreshAdapter implements HttpClientAdapter {
  int refreshCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/auth/token/refresh')) {
      refreshCalls++;
      final callNumber = refreshCalls;
      // Simulate latency so the two concurrent callers actually overlap.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return ResponseBody.fromString(
        jsonEncode({
          'access': 'new-access-$callNumber',
          'refresh': 'new-refresh-$callNumber',
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

DioException _make401(String path) {
  final options = RequestOptions(path: path);
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: 401),
  );
}

void main() {
  test('concurrent 401s collapse onto a single token refresh', () async {
    final prefs = await createTestSharedPreferences({
      AppConstants.keyAccessToken: 'expired-access',
      AppConstants.keyRefreshToken: 'valid-refresh',
    });
    final storage = TokenStorage(prefs);
    final config = ServerConfig(prefs);
    await config.save(domain: 'api.example.com', useHttps: true);

    final adapter = _CountingRefreshAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final interceptor = AuthInterceptor(storage, config);
    interceptor.setDio(dio);

    await Future.wait([
      interceptor.onError(_make401('/diaries/'), ErrorInterceptorHandler()),
      interceptor.onError(_make401('/tags/'), ErrorInterceptorHandler()),
    ]);

    expect(adapter.refreshCalls, 1);
    expect(
      await storage.read(key: AppConstants.keyAccessToken),
      'new-access-1',
    );
    expect(
      await storage.read(key: AppConstants.keyRefreshToken),
      'new-refresh-1',
    );
  });

  test(
    'a later 401 after the first refresh completes triggers a new refresh',
    () async {
      final prefs = await createTestSharedPreferences({
        AppConstants.keyAccessToken: 'expired-access',
        AppConstants.keyRefreshToken: 'valid-refresh',
      });
      final storage = TokenStorage(prefs);
      final config = ServerConfig(prefs);
      await config.save(domain: 'api.example.com', useHttps: true);

      final adapter = _CountingRefreshAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final interceptor = AuthInterceptor(storage, config);
      interceptor.setDio(dio);

      await interceptor.onError(
        _make401('/diaries/'),
        ErrorInterceptorHandler(),
      );
      await interceptor.onError(_make401('/tags/'), ErrorInterceptorHandler());

      expect(adapter.refreshCalls, 2);
    },
  );
}
