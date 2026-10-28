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
import '../../../shared/widgets/qadam_ui.dart';

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
        setState(
          () => _driverPosition = LatLng(position.latitude, position.longitude),
        );
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
      if (mounted) {
        setState(() => _loading = false);
        ref.read(offersProvider.notifier).state =
            List<Map<String, dynamic>>.from(offers);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Не удалось загрузить заказы';
        });
      }
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
          width: 52,
          height: 52,
          child: GestureDetector(
            onTap: () => _acceptOffer(rideId),
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: AppTheme.floatShadow,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.local_taxi_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                  Text(
                    '~${offer['eta_min'] ?? 0}',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
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
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.88, 0, 0, 0, 18,
              0, 0.91, 0, 0, 16,
              0, 0, 0.96, 0, 10,
              0, 0, 0, 1, 0,
            ]),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _driverPosition ?? _bishkek,
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.qadam.driver',
                ),
                if (_driverPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _driverPosition!,
                        width: 54,
                        height: 54,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: isOnline
                                ? AppTheme.brandGradient
                                : AppTheme.deepGradient,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: AppTheme.floatShadow,
                          ),
                          child: const Icon(
                            Icons.local_taxi_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (isOnline && offers.isNotEmpty)
                  MarkerLayer(markers: _buildOfferMarkers()),
              ],
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: QadamCard(
                  radius: 22,
                  padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                  child: Row(
                    children: [
                      const QadamWordmark(size: 18, subtitle: 'DRIVER'),
                      const Spacer(),
                      Text(
                        isOnline ? 'Онлайн' : 'Офлайн',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isOnline
                              ? AppTheme.success
                              : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Switch(
                        value: isOnline,
                        onChanged: _toggleOnline,
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppTheme.success,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Loading / error
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null && offers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: QadamCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const QadamIconBadge(
                        icon: Icons.wifi_off_rounded,
                        color: AppTheme.error,
                        size: 54,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      QadamActionButton(
                        label: 'Повторить',
                        onTap: _loadOffers,
                        style: QadamButtonStyle.soft,
                        height: 46,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Active offers count badge
          if (isOnline && offers.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 82,
              left: 16,
              right: 16,
              child: QadamGradientCard(
                radius: 20,
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Доступно заказов: ${offers.length}',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadOffers,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Обновить',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Recenter button
          Positioned(
            bottom: offers.isNotEmpty && isOnline ? 100 : 24,
            right: 16,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  if (_driverPosition != null) {
                    _mapController.move(_driverPosition!, 15);
                  }
                },
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.my_location_rounded,
                    size: 21,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
          ),

          // Accept first offer
          if (offers.isNotEmpty && isOnline)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: QadamActionButton(
                label: 'Взять заказ',
                icon: Icons.check_rounded,
                onTap: () {
                  final first = offers.first;
                  final rideId = first['ride_order_id'] as String?;
                  if (rideId != null) _acceptOffer(rideId);
                },
              ),
            ),
        ],
      ),
    );
  }
}
