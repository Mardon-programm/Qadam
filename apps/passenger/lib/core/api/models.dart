// Shared API response models for passenger app

class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String role;
  final String phone;

  const TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.role,
    required this.phone,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> j) => TokenResponse(
        accessToken: j['access_token'] as String,
        refreshToken: j['refresh_token'] as String,
        userId: j['user_id'] as String,
        role: j['role'] as String,
        phone: j['phone'] as String,
      );
}

class RideQuote {
  final double distanceKm;
  final double durationMin;
  final double quotedPrice;
  final String currency;
  final double surgeMultiplier;
  final double platformFeeEstimate;
  final double driverNetEstimate;

  const RideQuote({
    required this.distanceKm,
    required this.durationMin,
    required this.quotedPrice,
    required this.currency,
    required this.surgeMultiplier,
    required this.platformFeeEstimate,
    required this.driverNetEstimate,
  });

  factory RideQuote.fromJson(Map<String, dynamic> j) => RideQuote(
        distanceKm: _toDouble(j['distance_km']),
        durationMin: _toDouble(j['duration_min']),
        quotedPrice: _toDouble(j['quoted_price']),
        currency: j['currency'] as String? ?? 'KGS',
        surgeMultiplier: _toDouble(j['surge_multiplier']),
        platformFeeEstimate: _toDouble(j['platform_fee_estimate']),
        driverNetEstimate: _toDouble(j['driver_net_estimate']),
      );
}

class RideOrder {
  final String id;
  final String status;
  final String pickupAddress;
  final String dropoffAddress;
  final double? quotedPrice;
  final double? finalPrice;
  final double surgeMultiplier;
  final String currency;
  final String? driverId;
  final int? etaMin;

  const RideOrder({
    required this.id,
    required this.status,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.quotedPrice,
    this.finalPrice,
    required this.surgeMultiplier,
    required this.currency,
    this.driverId,
    this.etaMin,
  });

  factory RideOrder.fromJson(Map<String, dynamic> j) => RideOrder(
        id: j['id'] as String,
        status: j['status'] as String,
        pickupAddress: j['pickup_address'] as String,
        dropoffAddress: j['dropoff_address'] as String,
        quotedPrice: j['quoted_price'] != null ? _toDouble(j['quoted_price']) : null,
        finalPrice: j['final_price'] != null ? _toDouble(j['final_price']) : null,
        surgeMultiplier: _toDouble(j['surge_multiplier']),
        currency: j['currency'] as String? ?? 'KGS',
        driverId: j['driver_id'] as String?,
        etaMin: j['eta_min'] as int?,
      );

  bool get isActive => ![
        'completed',
        'cancelled',
        'failed',
      ].contains(status);
}

class IntercityTrip {
  final String id;
  final String driverId;
  final String originCity;
  final String destinationCity;
  final DateTime departAt;
  final double pricePerSeat;
  final String currency;
  final int seatCount;
  final int availableSeats;
  final String? meetingPoint;
  final String status;

  const IntercityTrip({
    required this.id,
    required this.driverId,
    required this.originCity,
    required this.destinationCity,
    required this.departAt,
    required this.pricePerSeat,
    required this.currency,
    required this.seatCount,
    required this.availableSeats,
    this.meetingPoint,
    required this.status,
  });

  factory IntercityTrip.fromJson(Map<String, dynamic> j) => IntercityTrip(
        id: j['id'] as String,
        driverId: j['driver_id'] as String,
        originCity: j['origin_city'] as String,
        destinationCity: j['destination_city'] as String,
        departAt: DateTime.parse(j['depart_at'] as String),
        pricePerSeat: _toDouble(j['price_per_seat']),
        currency: j['currency'] as String? ?? 'KGS',
        seatCount: j['seat_count'] as int,
        availableSeats: j['available_seats'] as int,
        meetingPoint: j['meeting_point'] as String?,
        status: j['status'] as String,
      );
}

class Booking {
  final String id;
  final String tripId;
  final String status;
  final List<String> seatCodes;
  final int passengerCount;
  final double totalPrice;
  final String currency;
  final String? paymentId;

  const Booking({
    required this.id,
    required this.tripId,
    required this.status,
    required this.seatCodes,
    required this.passengerCount,
    required this.totalPrice,
    required this.currency,
    this.paymentId,
  });

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'] as String,
        tripId: j['trip_id'] as String,
        status: j['status'] as String,
        seatCodes: (j['seat_codes'] as List).map((s) => s as String).toList(),
        passengerCount: j['passenger_count'] as int,
        totalPrice: _toDouble(j['total_price']),
        currency: j['currency'] as String? ?? 'KGS',
        paymentId: j['payment_id'] as String?,
      );
}

class SupportCase {
  final String id;
  final String caseType;
  final String status;
  final String subject;
  final String description;
  final String? resolution;

  const SupportCase({
    required this.id,
    required this.caseType,
    required this.status,
    required this.subject,
    required this.description,
    this.resolution,
  });

  factory SupportCase.fromJson(Map<String, dynamic> j) => SupportCase(
        id: j['id'] as String,
        caseType: j['case_type'] as String,
        status: j['status'] as String,
        subject: j['subject'] as String,
        description: j['description'] as String,
        resolution: j['resolution'] as String?,
      );
}

double _toDouble(dynamic v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.parse(v);
  return 0.0;
}
