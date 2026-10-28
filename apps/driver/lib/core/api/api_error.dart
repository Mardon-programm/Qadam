import 'package:dio/dio.dart';

/// Structured view of an API failure.
///
/// The backend returns errors as `{"code": "...", "message": "...",
/// "retry_after_seconds": 42}`. Validating errors keep the FastAPI shape with
/// a `detail` field, so both are handled here.
class ApiFailure {
  const ApiFailure({
    this.statusCode,
    this.code,
    this.message,
    this.retryAfterSeconds,
  });

  final int? statusCode;
  final String? code;
  final String? message;
  final int? retryAfterSeconds;

  bool get isRateLimited => statusCode == 429 || code == 'rate_limited';

  bool get isNetwork => statusCode == null;

  int get retryInMinutes {
    final seconds = retryAfterSeconds ?? 900;
    final minutes = (seconds / 60).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  static ApiFailure from(Object error) {
    if (error is! DioException) {
      return ApiFailure(message: error.toString());
    }
    final response = error.response;
    final body = _asMap(response?.data);
    final detail = body?['detail'];
    final detailMap = _asMap(detail);

    final code = body?['code']?.toString() ?? detailMap?['code']?.toString();
    final message = body?['message']?.toString() ??
        detailMap?['message']?.toString() ??
        (detail is String ? detail : null);
    final retryAfter = _toInt(
      body?['retry_after_seconds'] ?? detailMap?['retry_after_seconds'],
    );

    return ApiFailure(
      statusCode: response?.statusCode,
      code: code,
      message: message,
      retryAfterSeconds: retryAfter,
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
