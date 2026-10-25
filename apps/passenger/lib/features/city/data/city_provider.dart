import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/api/models.dart';

// Active ride tracking
final activeRideProvider = StateProvider<RideOrder?>((ref) => null);

// Quote state
final quoteProvider = StateProvider<RideQuote?>((ref) => null);

// Loading indicators
final rideLoadingProvider = StateProvider<bool>((ref) => false);

// Notifier for city ride actions
final cityRideNotifierProvider =
    AsyncNotifierProvider<CityRideNotifier, RideOrder?>(
  CityRideNotifier.new,
);

class CityRideNotifier extends AsyncNotifier<RideOrder?> {
  @override
  Future<RideOrder?> build() async => null;

  Future<RideQuote> quote({
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    final api = ref.read(apiServiceProvider);
    final q = await api.getQuote(
      pickupAddress: pickupAddress,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffAddress: dropoffAddress,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
    );
    ref.read(quoteProvider.notifier).state = q;
    return q;
  }

  Future<RideOrder> createRide({
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    state = const AsyncValue.loading();
    final api = ref.read(apiServiceProvider);
    try {
      final ride = await api.createRide(
        pickupAddress: pickupAddress,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffAddress: dropoffAddress,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
      );
      state = AsyncValue.data(ride);
      ref.read(activeRideProvider.notifier).state = ride;
      return ride;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      rethrow;
    }
  }

  Future<void> cancelRide(String rideId) async {
    final api = ref.read(apiServiceProvider);
    final updated = await api.cancelRide(rideId);
    state = AsyncValue.data(updated);
    ref.read(activeRideProvider.notifier).state = null;
  }

  Future<void> refreshRide(String rideId) async {
    final api = ref.read(apiServiceProvider);
    final updated = await api.getRide(rideId);
    state = AsyncValue.data(updated);
    if (!updated.isActive) {
      ref.read(activeRideProvider.notifier).state = null;
    } else {
      ref.read(activeRideProvider.notifier).state = updated;
    }
  }
}
