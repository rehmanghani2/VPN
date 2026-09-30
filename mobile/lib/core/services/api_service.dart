import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'storage_service.dart';

class ApiService {
  final StorageService _storage;
  late final Dio _dio;

  ApiService(this._storage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _storage.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshToken = _storage.refreshToken;
            if (refreshToken != null) {
              try {
                // Attempt token refresh
                final refreshRes = await _dio.post(
                  ApiConstants.refresh,
                  data: {'refreshToken': refreshToken},
                  options: Options(headers: {}),
                );

                final newAccess = refreshRes.data['accessToken'];
                final newRefresh = refreshRes.data['refreshToken'];

                await _storage.saveTokens(access: newAccess, refresh: newRefresh);

                // Retry original request
                final clonedReq = error.requestOptions;
                clonedReq.headers['Authorization'] = 'Bearer $newAccess';
                final response = await _dio.fetch(clonedReq);
                return handler.resolve(response);
              } catch (_) {
                await _storage.clearTokens();
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Dio get client => _dio;
}
