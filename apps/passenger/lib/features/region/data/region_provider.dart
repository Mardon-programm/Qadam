import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/api/models.dart';

final tripSearchProvider =
    AsyncNotifierProvider.family<TripSearchNotifier, List<IntercityTrip>, Map<String, String>>(
  TripSearchNotifier.new,
);

class TripSearchNotifier
    extends FamilyAsyncNotifier<List<IntercityTrip>, Map<String, String>> {
  @override
  Future<List<IntercityTrip>> build(Map<String, String> arg) async {
    final api = ref.read(apiServiceProvider);
    return api.searchTrips(
      origin: arg['origin'] ?? '',
      destination: arg['destination'] ?? '',
    );
  }
}

final myBookingsProvider =
    AsyncNotifierProvider<MyBookingsNotifier, List<Booking>>(
  MyBookingsNotifier.new,
);

class MyBookingsNotifier extends AsyncNotifier<List<Booking>> {
  @override
  Future<List<Booking>> build() async {
    final api = ref.read(apiServiceProvider);
    return api.getMyBookings();
  }

  Future<Booking> createBooking({
    required String tripId,
    int passengerCount = 1,
    int baggageCount = 0,
  }) async {
    final api = ref.read(apiServiceProvider);
    final booking = await api.createBooking(
      tripId: tripId,
      passengerCount: passengerCount,
      baggageCount: baggageCount,
    );
    state = AsyncValue.data([booking, ...?state.valueOrNull]);
    return booking;
  }

  Future<void> cancelBooking(String bookingId) async {
    final api = ref.read(apiServiceProvider);
    await api.cancelBooking(bookingId);
    ref.invalidateSelf();
  }
}
