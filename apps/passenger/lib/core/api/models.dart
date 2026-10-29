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
  final double trafficMultiplier;
  final double demandMultiplier;
  final String congestion;
  final String routeSource;
  final List<List<double>> routeGeometry;
  final double platformFeeEstimate;
  final double driverNetEstimate;

  const RideQuote({
    required this.distanceKm,
    required this.durationMin,
    required this.quotedPrice,
    required this.currency,
    required this.surgeMultiplier,
    this.trafficMultiplier = 1.0,
    this.demandMultiplier = 1.0,
    this.congestion = 'unknown',
    this.routeSource = 'estimate',
    this.routeGeometry = const [],
    required this.platformFeeEstimate,
    required this.driverNetEstimate,
  });

  factory RideQuote.fromJson(Map<String, dynamic> j) => RideQuote(
        distanceKm: _toDouble(j['distance_km']),
        durationMin: _toDouble(j['duration_min']),
        quotedPrice: _toDouble(j['quoted_price']),
        currency: j['currency'] as String? ?? 'KGS',
        surgeMultiplier: _toDouble(j['surge_multiplier']),
        trafficMultiplier: _toDouble(j['traffic_multiplier']),
        demandMultiplier: _toDouble(j['demand_multiplier']),
        congestion: j['congestion'] as String? ?? 'unknown',
        routeSource: j['route_source'] as String? ?? 'estimate',
        routeGeometry: (j['route_geometry'] as List?)
                ?.whereType<List>()
                .map((p) => p.map(_toDouble).toList())
                .toList() ??
            const [],
        platformFeeEstimate: _toDouble(j['platform_fee_estimate']),
        driverNetEstimate: _toDouble(j['driver_net_estimate']),
      );
}

class DriverInfo {
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String? rating;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? vehiclePlate;

  const DriverInfo({
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.rating,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleColor,
    this.vehiclePlate,
  });

  String get vehicleTitle {
    final parts = [vehicleMake, vehicleModel, vehicleColor]
        .where((e) => e != null && e!.isNotEmpty)
        .map((e) => e!)
        .toList();
    return parts.isEmpty ? 'Автомобиль' : parts.join(' · ');
  }

  String get plate => vehiclePlate ?? '';

  factory DriverInfo.fromJson(Map<String, dynamic> j) => DriverInfo(
        fullName: j['full_name'] as String?,
        phone: j['phone'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        rating: j['rating'] as String?,
        vehicleMake: j['vehicle_make'] as String?,
        vehicleModel: j['vehicle_model'] as String?,
        vehicleColor: j['vehicle_color'] as String?,
        vehiclePlate: j['vehicle_plate'] as String?,
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
  final double? distanceKm;
  final double? durationMin;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final DriverInfo? driver;
  final double? driverLat;
  final double? driverLng;

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
    this.distanceKm,
    this.durationMin,
    this.createdAt,
    this.completedAt,
    this.driver,
    this.driverLat,
    this.driverLng,
  });

  factory RideOrder.fromJson(Map<String, dynamic> j) => RideOrder(
        id: j['id'] as String,
        status: j['status'] as String,
        pickupAddress: j['pickup_address'] as String,
        dropoffAddress: j['dropoff_address'] as String,
        quotedPrice:
            j['quoted_price'] != null ? _toDouble(j['quoted_price']) : null,
        finalPrice:
            j['final_price'] != null ? _toDouble(j['final_price']) : null,
        surgeMultiplier: _toDouble(j['surge_multiplier']),
        currency: j['currency'] as String? ?? 'KGS',
        driverId: j['driver_id'] as String?,
        etaMin: j['eta_min'] as int?,
        distanceKm:
            j['distance_km'] != null ? _toDouble(j['distance_km']) : null,
        durationMin:
            j['duration_min'] != null ? _toDouble(j['duration_min']) : null,
        createdAt: _toDate(j['created_at']),
        completedAt: _toDate(j['completed_at']),
        driver: j['driver'] is Map
            ? DriverInfo.fromJson((j['driver'] as Map).cast<String, dynamic>())
            : null,
        driverLat: j['driver_lat'] != null ? _toDouble(j['driver_lat']) : null,
        driverLng: j['driver_lng'] != null ? _toDouble(j['driver_lng']) : null,
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
  final DateTime? createdAt;
  final String? originCity;
  final String? destinationCity;
  final DateTime? departAt;

  const Booking({
    required this.id,
    required this.tripId,
    required this.status,
    required this.seatCodes,
    required this.passengerCount,
    required this.totalPrice,
    required this.currency,
    this.paymentId,
    this.createdAt,
    this.originCity,
    this.destinationCity,
    this.departAt,
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
        createdAt: _toDate(j['created_at']),
        originCity: j['origin_city'] as String?,
        destinationCity: j['destination_city'] as String?,
        departAt: _toDate(j['depart_at']),
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

class PlaceSuggestion {
  final String name;
  final String address;
  final String fullAddress;
  final double lat;
  final double lng;

  const PlaceSuggestion({
    required this.name,
    required this.address,
    required this.fullAddress,
    required this.lat,
    required this.lng,
  });

  /// "259, улица Токтогула" is a bad title; fall back to the street part.
  String get title => RegExp(r'^[\d\s-]+$').hasMatch(name)
      ? (address.split(',').first.trim().isEmpty ? fullAddress : address.split(',').first.trim())
      : name;

  String get subtitle {
    final rest = address.trim();
    return rest.isEmpty ? fullAddress : rest;
  }

  factory PlaceSuggestion.fromJson(Map<String, dynamic> j) => PlaceSuggestion(
        name: j['name'] as String? ?? '',
        address: j['address'] as String? ?? '',
        fullAddress: j['full_address'] as String? ?? '',
        lat: _toDouble(j['lat']),
        lng: _toDouble(j['lng']),
      );
}

class MapConfig {
  final String? trafficTileUrl;
  final String? trafficAttribution;

  const MapConfig({this.trafficTileUrl, this.trafficAttribution});

  bool get hasTraffic => trafficTileUrl != null && trafficTileUrl!.isNotEmpty;

  factory MapConfig.fromJson(Map<String, dynamic> j) => MapConfig(
        trafficTileUrl: j['traffic_tile_url'] as String?,
        trafficAttribution: j['traffic_attribution'] as String?,
      );
}

double _toDouble(dynamic v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.parse(v);
  return 0.0;
}

DateTime? _toDate(dynamic v) {
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}
