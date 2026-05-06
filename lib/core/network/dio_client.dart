import 'package:dio/dio.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';
import 'server_config.dart';

class DioClient {
  late final Dio dio;
  late final AuthInterceptor authInterceptor;

  DioClient(ServerConfig config, TokenStorage storage) {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    authInterceptor = AuthInterceptor(storage, config);
    authInterceptor.setDio(dio);
    dio.interceptors.add(authInterceptor);
  }

  String baseUrl(ServerConfig config) => config.baseUrl;
}
