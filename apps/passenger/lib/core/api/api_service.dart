import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'models.dart';

class ApiService {
  ApiService(this._dio);
  final Dio _dio;

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> requestOtp(String phone) async {
    final r = await _dio.post('/auth/otp/request', data: {
      'phone': phone,
      'role': 'passenger',
    });
    return r.data as Map<String, dynamic>;
  }

  Future<TokenResponse> verifyOtp(
    String phone,
    String code, {
    String? fullName,
    String? nickname,
  }) async {
    final r = await _dio.post('/auth/otp/verify', data: {
      'phone': phone,
      'code': code,
      'role': 'passenger',
      if (fullName != null) 'full_name': fullName,
      if (nickname != null) 'nickname': nickname,
    });
    return TokenResponse.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getMe() async {
    final r = await _dio.get('/auth/me');
    return r.data as Map<String, dynamic>;
  }

  // ── City rides ─────────────────────────────────────────────────────────────

  Future<RideQuote> getQuote({
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
    double surge = 1.0,
  }) async {
    final r = await _dio.post('/city/quote', data: {
      'pickup_address': pickupAddress,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_address': dropoffAddress,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'surge': surge,
    });
    return RideQuote.fromJson(r.data as Map<String, dynamic>);
  }

  Future<RideOrder> createRide({
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
    double surge = 1.0,
    String? idempotencyKey,
  }) async {
    final r = await _dio.post('/city/rides', data: {
      'pickup_address': pickupAddress,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_address': dropoffAddress,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'surge': surge,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    });
    return RideOrder.fromJson(r.data as Map<String, dynamic>);
  }

  Future<RideOrder> getRide(String rideId) async {
    final r = await _dio.get('/city/rides/$rideId');
    return RideOrder.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<RideOrder>> getMyRides() async {
    final r = await _dio.get('/city/rides');
    return (r.data as List)
        .map((e) => RideOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Geo / maps ─────────────────────────────────────────────────────────────

  Future<MapConfig> getMapConfig() async {
    final r = await _dio.get('/geo/map-config');
    return MapConfig.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    double? lat,
    double? lng,
    int limit = 6,
  }) async {
    final r = await _dio.get('/geo/search', queryParameters: {
      'q': query,
      'limit': limit,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
    final items = (r.data as Map<String, dynamic>)['items'] as List? ?? [];
    return items
        .map((e) => PlaceSuggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PlaceSuggestion?> reversePlace(double lat, double lng) async {
    final r = await _dio.get('/geo/reverse', queryParameters: {
      'lat': lat,
      'lng': lng,
    });
    final place = (r.data as Map<String, dynamic>)['place'];
    if (place is! Map) return null;
    return PlaceSuggestion.fromJson(place.cast<String, dynamic>());
  }

  Future<RideOrder> cancelRide(String rideId, {String reason = 'user_cancelled'}) async {
    final r = await _dio.post('/city/rides/$rideId/cancel', data: {'reason': reason});
    return RideOrder.fromJson(r.data as Map<String, dynamic>);
  }

  // ── Region ─────────────────────────────────────────────────────────────────

  Future<List<IntercityTrip>> searchTrips({
    String origin = '',
    String destination = '',
  }) async {
    final r = await _dio.get('/region/trips', queryParameters: {
      if (origin.isNotEmpty) 'origin': origin,
      if (destination.isNotEmpty) 'destination': destination,
    });
    return (r.data as List)
        .map((t) => IntercityTrip.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<Booking> createBooking({
    required String tripId,
    int passengerCount = 1,
    int baggageCount = 0,
    String? idempotencyKey,
  }) async {
    final r = await _dio.post('/region/bookings', data: {
      'trip_id': tripId,
      'passenger_count': passengerCount,
      'baggage_count': baggageCount,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    });
    return Booking.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<Booking>> getMyBookings() async {
    final r = await _dio.get('/region/bookings');
    return (r.data as List)
        .map((b) => Booking.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  Future<Booking> cancelBooking(String bookingId) async {
    final r = await _dio.post('/region/bookings/$bookingId/cancel');
    return Booking.fromJson(r.data as Map<String, dynamic>);
  }

  // ── Support ────────────────────────────────────────────────────────────────

  Future<SupportCase> openCase({
    required String caseType,
    required String subject,
    required String description,
    String? referenceType,
    String? referenceId,
  }) async {
    final r = await _dio.post('/support', data: {
      'case_type': caseType,
      'subject': subject,
      'description': description,
      if (referenceType != null) 'reference_type': referenceType,
      if (referenceId != null) 'reference_id': referenceId,
    });
    return SupportCase.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<SupportCase>> getMyCases() async {
    final r = await _dio.get('/support/my');
    return (r.data as List)
        .map((c) => SupportCase.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  // ── Generic HTTP ────────────────────────────────────────────────────────────

  Future<Response<T>> get<T>(String path,
      {Map<String, dynamic>? queryParameters}) async {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(String path,
      {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return _dio.post(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<T>> delete<T>(String path,
      {Map<String, dynamic>? queryParameters}) async {
    return _dio.delete(path, queryParameters: queryParameters);
  }

  Future<Response<T>> put<T>(String path,
      {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return _dio.put(path, data: data, queryParameters: queryParameters);
  }
}

final apiServiceProvider = Provider<ApiService>(
  (ref) => ApiService(ref.watch(dioProvider)),
);
