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
    this.type,
    this.raw,
  });

  final int? statusCode;
  final String? code;
  final String? message;
  final int? retryAfterSeconds;
  final DioExceptionType? type;
  final String? raw;

  bool get isRateLimited => statusCode == 429 || code == 'rate_limited';

  bool get isTimeout =>
      type == DioExceptionType.connectionTimeout ||
      type == DioExceptionType.sendTimeout ||
      type == DioExceptionType.receiveTimeout;

  bool get isConnectionError => type == DioExceptionType.connectionError;

  /// True when the request likely didn't reach a healthy server (no HTTP status).
  /// Kept for backward compatibility with existing call sites.
  bool get isNetwork => statusCode == null && (isTimeout || isConnectionError || type == DioExceptionType.unknown || type == null);

  String get displayMessage {
    if (isRateLimited) {
      return 'Слишком много попыток. Повторите позже.';
    }
    if (isTimeout) {
      return 'Сервер не отвечает. Проверьте интернет и попробуйте снова (сервис может запускаться). [${type?.name}]';
    }
    if (isConnectionError || (statusCode == null && type != DioExceptionType.badResponse)) {
      final detail = (raw != null && raw!.trim().isNotEmpty)
          ? ' ${raw!}'
          : (message != null && message!.trim().isNotEmpty ? ' ${message!}' : '');
      return 'Не удалось подключиться к серверу. Проверьте интернет (Wi‑Fi/мобильный) и попробуйте снова. [${type?.name ?? "unknown"}]$detail';
    }
    if (message != null && message!.trim().isNotEmpty) return message!;
    if (statusCode != null) return 'Ошибка сервера ($statusCode).';
    return 'Произошла ошибка. Попробуйте снова. [${type?.name ?? "error"}]';
  }

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

    final raw = error.error?.toString() ?? error.message;
    return ApiFailure(
      statusCode: response?.statusCode,
      code: code,
      message: message,
      retryAfterSeconds: retryAfter,
      type: error.type,
      raw: raw,
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
