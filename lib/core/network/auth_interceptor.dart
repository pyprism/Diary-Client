import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../errors/app_exception.dart';
import '../storage/token_storage.dart';
import 'server_config.dart';

class AuthInterceptor extends Interceptor {
  final TokenStorage _storage;
  final ServerConfig _config;
  Dio? _dio;

  AuthInterceptor(this._storage, this._config);

  void setDio(Dio dio) => _dio = dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] == true) {
      handler.next(options);
      return;
    }
    final token = await _storage.read(key: AppConstants.keyAccessToken);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isRefreshRequest =
        err.requestOptions.path.contains('/auth/token/refresh/');
    final alreadyRetried =
        err.requestOptions.extra['tokenRefreshRetried'] == true;

    if (err.response?.statusCode == 401 &&
        !isRefreshRequest &&
        !alreadyRetried) {
      final refreshToken =
          await _storage.read(key: AppConstants.keyRefreshToken);
      if (refreshToken != null && _dio != null) {
        try {
          final res = await _dio!.post(
            _config.endpoint('auth/token/refresh'),
            data: {'refresh': refreshToken},
            options: Options(headers: {}, extra: {'skipAuth': true}),
          );
          final newAccess = res.data['access'] as String;
          final newRefresh = res.data['refresh'] as String?;
          await _storage.write(
              key: AppConstants.keyAccessToken, value: newAccess);
          if (newRefresh != null && newRefresh.isNotEmpty) {
            await _storage.write(
                key: AppConstants.keyRefreshToken, value: newRefresh);
          }

          // Retry original request
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newAccess';
          opts.extra['tokenRefreshRetried'] = true;
          final retryRes = await _dio!.fetch(opts);
          return handler.resolve(retryRes);
        } catch (_) {
          await _storage.deleteAll([
            AppConstants.keyAccessToken,
            AppConstants.keyRefreshToken,
          ]);
          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error:
                  const AuthException('Session expired. Please log in again.'),
            ),
          );
        }
      }
    }
    handler.next(_mapError(err));
  }

  DioException _mapError(DioException err) {
    final status = err.response?.statusCode;
    final data = err.response?.data;
    String message = 'An error occurred';

    if (data is Map) {
      if (data['detail'] != null) {
        message = data['detail'].toString();
      } else if (data['non_field_errors'] != null) {
        message = (data['non_field_errors'] as List).join(', ');
      } else {
        final fields = data.entries
            .where((e) => e.value is List)
            .map((e) => '${e.key}: ${(e.value as List).join(', ')}')
            .join('\n');
        if (fields.isNotEmpty) message = fields;
      }
    }

    return DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      error: status == 401
          ? AuthException(message, statusCode: status)
          : status == 404
              ? NotFoundException(message)
              : status != null && status >= 400 && status < 500
                  ? ValidationException(message, statusCode: status)
                  : NetworkException(message, statusCode: status),
    );
  }
}
