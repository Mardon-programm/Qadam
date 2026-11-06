import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  // Render production API
  defaultValue: 'https://qadam-nc9f.onrender.com/api/v1',
);

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
const _accessKey = 'access_token';
const _refreshKey = 'refresh_token';

// ── Token storage helpers ──────────────────────────────────────────────────

Future<void> saveTokens(String access, String refresh) async {
  try {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  } catch (_) {
    try {
      await _storage.deleteAll(
        aOptions: const AndroidOptions(encryptedSharedPreferences: true),
      );
    } catch (_) {}
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }
}

Future<String?> readAccessToken() async {
  try {
    return await _storage.read(key: _accessKey);
  } catch (_) {
    await clearTokens();
    return null;
  }
}

Future<String?> readRefreshToken() async {
  try {
    return await _storage.read(key: _refreshKey);
  } catch (_) {
    await clearTokens();
    return null;
  }
}

Future<void> clearTokens() async {
  try {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  } catch (_) {
    try {
      await _storage.deleteAll(
        aOptions: const AndroidOptions(encryptedSharedPreferences: true),
      );
    } catch (_) {}
  }
}

// ── Dio instance ────────────────────────────────────────────────────────────

Dio _buildDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(_AuthInterceptor(dio));
  return dio;
}

class _AuthInterceptor extends Interceptor {
  final Dio dio;
  _AuthInterceptor(this.dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await readAccessToken();
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
    if (err.response?.statusCode == 401) {
      final refreshToken = await readRefreshToken();
      if (refreshToken != null) {
        try {
          final resp = await Dio(BaseOptions(baseUrl: _baseUrl)).post(
            '/auth/refresh',
            data: {'refresh_token': refreshToken},
          );
          final newAccess = resp.data['access_token'] as String;
          final newRefresh = resp.data['refresh_token'] as String;
          await saveTokens(newAccess, newRefresh);
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
          final retried = await dio.fetch(err.requestOptions);
          return handler.resolve(retried);
        } catch (_) {
          await clearTokens();
        }
      }
    }
    handler.next(err);
  }
}

final dioProvider = Provider<Dio>((ref) => _buildDio());
