import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  // Render production API
  defaultValue: 'https://qadam-nc9f.onrender.com/api/v1',
);

const _storage = FlutterSecureStorage();
const _accessKey = 'access_token';
const _refreshKey = 'refresh_token';

Future<void> saveTokens(String a, String r) async {
  await _storage.write(key: _accessKey, value: a);
  await _storage.write(key: _refreshKey, value: r);
}

Future<String?> readAccessToken() => _storage.read(key: _accessKey);
Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);
Future<void> clearTokens() async {
  await _storage.deleteAll();
}

Dio _buildDio() {
  final dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));
  dio.interceptors.add(_AuthInterceptor(dio));
  return dio;
}

class _AuthInterceptor extends Interceptor {
  final Dio dio;
  _AuthInterceptor(this.dio);

  @override
  Future<void> onRequest(RequestOptions o, RequestInterceptorHandler h) async {
    final token = await readAccessToken();
    if (token != null) o.headers['Authorization'] = 'Bearer $token';
    h.next(o);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler h) async {
    if (err.response?.statusCode == 401) {
      final rt = await readRefreshToken();
      if (rt != null) {
        try {
          final r = await Dio(BaseOptions(baseUrl: _baseUrl))
              .post('/auth/refresh', data: {'refresh_token': rt});
          await saveTokens(r.data['access_token'], r.data['refresh_token']);
          err.requestOptions.headers['Authorization'] =
              'Bearer ${r.data['access_token']}';
          return h.resolve(await dio.fetch(err.requestOptions));
        } catch (_) {
          await clearTokens();
        }
      }
    }
    h.next(err);
  }
}

final dioProvider = Provider<Dio>((ref) => _buildDio());

// ── Driver API Service ──────────────────────────────────────────────────────

class DriverApiService {
  DriverApiService(this._dio);
  final Dio _dio;

  // Auth
  Future<Map<String, dynamic>> requestOtp(String phone) async {
    final r = await _dio.post('/auth/otp/request',
        data: {'phone': phone, 'role': 'driver'});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String code,
      {String? fullName}) async {
    final r = await _dio.post('/auth/otp/verify', data: {
      'phone': phone,
      'code': code,
      'role': 'driver',
      if (fullName != null) 'full_name': fullName,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final r = await _dio.get('/auth/me');
    return r.data as Map<String, dynamic>;
  }

  // Driver profile
  Future<Map<String, dynamic>> getProfile() async {
    final r = await _dio.get('/driver/profile');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setOnline(bool online) async {
    final r = await _dio.post('/driver/online', data: {'online': online});
    return r.data as Map<String, dynamic>;
  }

  Future<void> updateLocation(double lat, double lng) async {
    await _dio.post('/driver/location', data: {'lat': lat, 'lng': lng});
  }

  // Vehicles
  Future<List<dynamic>> getVehicles() async {
    final r = await _dio.get('/driver/vehicles');
    return r.data as List;
  }

  Future<Map<String, dynamic>> addVehicle(Map<String, dynamic> data) async {
    final r = await _dio.post('/driver/vehicles', data: data);
    return r.data as Map<String, dynamic>;
  }

  // Documents
  Future<List<dynamic>> getDocuments() async {
    final r = await _dio.get('/driver/documents');
    return r.data as List;
  }

  Future<Map<String, dynamic>> uploadDocument(Map<String, dynamic> data) async {
    final r = await _dio.post('/driver/documents', data: data);
    return r.data as Map<String, dynamic>;
  }

  // City offers
  Future<List<dynamic>> getOffers() async {
    final r = await _dio.get('/city/driver/offers');
    return r.data as List;
  }

  Future<Map<String, dynamic>> acceptRide(String rideId) async {
    final r = await _dio.post('/city/rides/$rideId/accept');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> startRide(String rideId) async {
    final r = await _dio.post('/city/rides/$rideId/start');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeRide(String rideId) async {
    final r = await _dio.post('/city/rides/$rideId/complete');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelRide(String rideId, String reason) async {
    final r = await _dio
        .post('/city/rides/$rideId/cancel', data: {'reason': reason});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getRide(String rideId) async {
    final r = await _dio.get('/city/rides/$rideId');
    return r.data as Map<String, dynamic>;
  }

  // Region trips
  Future<List<dynamic>> getMyTrips() async {
    final r = await _dio.get('/region/driver/trips');
    return r.data as List;
  }

  Future<Map<String, dynamic>> createTrip(Map<String, dynamic> data) async {
    final r = await _dio.post('/region/trips', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateTripStatus(
      String tripId, String status) async {
    final r = await _dio
        .patch('/region/trips/$tripId/status', data: {'status': status});
    return r.data as Map<String, dynamic>;
  }

  // Subscription
  Future<Map<String, dynamic>?> getCurrentSubscription() async {
    try {
      final r = await _dio.get('/subscriptions/current');
      if (r.data == null) return null;
      return r.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> subscribe(String plan) async {
    final r = await _dio.post('/subscriptions', data: {'plan': plan});
    return r.data as Map<String, dynamic>;
  }

  // Wallet
  Future<Map<String, dynamic>> getWalletHistory() async {
    final r = await _dio.get('/payments/wallet/history');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getWalletBalance() async {
    final r = await _dio.get('/payments/wallet/balance');
    return r.data as Map<String, dynamic>;
  }

  // Support
  Future<Map<String, dynamic>> openSupportCase(Map<String, dynamic> data) async {
    final r = await _dio.post('/support', data: data);
    return r.data as Map<String, dynamic>;
  }

  // Earnings
  Future<Map<String, dynamic>> getEarningsStats() async {
    final r = await _dio.get('/payments/wallet/balance');
    return r.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getCompletedTrips() async {
    final r = await _dio.get('/region/driver/trips');
    return r.data as List;
  }
}

final driverApiProvider =
    Provider<DriverApiService>((ref) => DriverApiService(ref.watch(dioProvider)));
