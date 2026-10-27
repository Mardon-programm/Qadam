import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';

// Default centre: Bishkek
const _bishkek = LatLng(42.8746, 74.5698);

final isOnlineProvider = StateProvider<bool>((ref) => false);
final offersProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  bool _loading = true;
  String? _error;
  StreamSubscription<Position>? _positionStream;
  LatLng? _driverPosition;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadOffers();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      var status = await Permission.location.status;
      if (!status.isGranted) {
        status = await Permission.location.request();
      }
      if (!status.isGranted) {
        if (mounted) setState(() => _driverPosition = _bishkek);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) {
        setState(() => _driverPosition = LatLng(position.latitude, position.longitude));
        _mapController.move(_driverPosition!, 15);
      }

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((p) {
        if (!mounted) return;
        setState(() => _driverPosition = LatLng(p.latitude, p.longitude));
      });
    } catch (e) {
      if (mounted) setState(() => _driverPosition = _bishkek);
    }
  }

  Future<void> _loadOffers() async {
    try {
      final api = ref.read(driverApiProvider);
      final offers = await api.getOffers();
      if (mounted) setState(() {
        _loading = false;
        ref.read(offersProvider.notifier).state = List<Map<String, dynamic>>.from(offers);
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'Не удалось загрузить заказы: $e';
      });
    }
  }

  Future<void> _toggleOnline(bool newVal) async {
    try {
      final api = ref.read(driverApiProvider);
      final result = await api.setOnline(newVal);
      if (mounted) {
        ref.read(isOnlineProvider.notifier).state =
            result['online_status'] == 'online';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['online_status'] == 'online'
                  ? 'Вы онлайн'
                  : 'Вы офлайн',
            ),
            backgroundColor: AppTheme.secondary,
          ),
        );
        // Reload offers when going online
        if (newVal == true) _loadOffers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _acceptOffer(String rideOrderId) async {
    try {
      final api = ref.read(driverApiProvider);
      await api.acceptRide(rideOrderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заказ принят! Едьте к пассажиру.'),
            backgroundColor: AppTheme.secondary,
          ),
        );
        _loadOffers();
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  List<Marker> _buildOfferMarkers() {
    final markers = <Marker>[];
    final offers = ref.read(offersProvider);
    for (final offer in offers) {
      final rideId = offer['ride_order_id'] as String?;
      if (rideId == null) continue;
      // Use offer index as pseudo-location offset so markers don't overlap exactly
      final idx = offers.indexOf(offer);
      final lat = _bishkek.latitude + (idx % 3) * 0.01 - 0.01;
      final lng = _bishkek.longitude + (idx ~/ 3) * 0.01 - 0.01;
      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () => _acceptOffer(rideId),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_taxi, color: Colors.white, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    '~${offer['eta_min'] ?? 0} мин',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final offers = ref.watch(offersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Карта заказов'),
        centerTitle: true,
        actions: [
          Switch(
            value: isOnline,
            onChanged: _toggleOnline,
            activeColor: Colors.white,
            activeTrackColor: AppTheme.secondary.withOpacity(0.6),
          ),
          const SizedBox(width: 12),
          Text(
            isOnline ? 'Онлайн' : 'Офлайн',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _driverPosition ?? _bishkek,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.qadam.driver',
              ),
              // Driver marker
              if (_driverPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _driverPosition!,
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isOnline ? AppTheme.secondary : AppTheme.textSecondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.local_taxi, color: Colors.white, size: 28),
                      ),
                    ),
                  ],
                ),
              // Offer markers
              if (isOnline && offers.isNotEmpty)
                MarkerLayer(
                  markers: _buildOfferMarkers(),
                ),
            ],
          ),

          // Loading / error
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null && offers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.error, size: 48),
                    const SizedBox(height: 8),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.error)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadOffers,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),

          // Active offers count badge
          if (isOnline && offers.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: AppTheme.primary,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.notification_add, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Доступно заказов: ${offers.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Обновить',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Recenter button
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: () {
                if (_driverPosition != null) {
                  _mapController.move(_driverPosition!, 15);
                }
              },
              child: const Icon(Icons.my_location, size: 20),
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
      floatingActionButton: offers.isNotEmpty && isOnline
          ? FloatingActionButton.extended(
              onPressed: () {
                // Accept first available offer
                final first = offers.first;
                final rideId = first['ride_order_id'] as String?;
                if (rideId != null) _acceptOffer(rideId);
              },
              icon: const Icon(Icons.check),
              label: const Text('Взять заказ'),
              backgroundColor: AppTheme.earningsGreen,
            )
          : null,
    );
  }
}
