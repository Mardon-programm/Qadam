import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/api/api_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_button.dart';
import '../data/city_provider.dart';

// Default centre: Bishkek
const _bishkek = LatLng(42.8746, 74.5698);

class CityMapScreen extends ConsumerStatefulWidget {
  const CityMapScreen({super.key});

  @override
  ConsumerState<CityMapScreen> createState() => _CityMapScreenState();
}

class _CityMapScreenState extends ConsumerState<CityMapScreen> {
  final _mapController = MapController();
  final _polygonPoints = <LatLng>[];

  LatLng? _pickup;
  LatLng? _dropoff;
  String _pickupAddress = '';
  String _dropoffAddress = '';
  bool _loadingLocation = true;
  String? _locationError;
  bool _showQuote = false;

  StreamSubscription<Position>? _positionStream;
  DateTime _lastQuoteAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    setState(() => _loadingLocation = true);
    try {
      // Check permissions
      var status = await Permission.location.status;
      if (!status.isGranted) {
        status = await Permission.location.request();
      }
      if (!status.isGranted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _locationError = l10n.needLocation;
          _loadingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final pos = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _pickup = pos;
          _pickupAddress = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          _loadingLocation = false;
        });
        _mapController.move(pos, 15);

        // Listen to location updates to keep pin near user
        _positionStream = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((p) {
          if (!mounted) return;
          setState(() {
            _pickup = LatLng(p.latitude, p.longitude);
            _pickupAddress =
                '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}';
          });
          _updateRoute();
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _locationError = '${l10n.locationError}: $e';
          _loadingLocation = false;
        });
      }
    }
  }

  void _onMapTap(TapPosition _, LatLng point) {
    setState(() {
      if (_pickup == null) {
        _pickup = point;
        _pickupAddress = '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
      } else if (_dropoff == null) {
        _dropoff = point;
        _dropoffAddress = '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
      } else {
        // Both set — tapping again resets dropoff
        _dropoff = point;
        _dropoffAddress = '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
      }
    });
    _updateRoute();
  }

  Future<void> _updateRoute() async {
    if (_pickup != null && _dropoff != null) {
      // Visual line only; real distance/price come from the backend (OSRM).
      final start = _pickup!;
      final end = _dropoff!;
      final points = <LatLng>[];
      const steps = 20;
      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        final lat = start.latitude + (end.latitude - start.latitude) * t;
        final lng = start.longitude + (end.longitude - start.longitude) * t;
        points.add(LatLng(lat, lng));
      }
      setState(() {
        _polygonPoints
          ..clear()
          ..addAll(points);
        _showQuote = true;
      });

      // The bottom sheet reads the quote from this provider; without this
      // request it would spin forever and the order button never appears.
      final now = DateTime.now();
      if (now.difference(_lastQuoteAt) < const Duration(seconds: 8)) return;
      _lastQuoteAt = now;
      ref.read(quoteProvider.notifier).state = null;
      try {
        await ref.read(cityRideNotifierProvider.notifier).quote(
              pickupAddress: _pickupAddress,
              pickupLat: start.latitude,
              pickupLng: start.longitude,
              dropoffAddress: _dropoffAddress,
              dropoffLat: end.latitude,
              dropoffLng: end.longitude,
            );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось рассчитать стоимость: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } else {
      setState(() {
        _polygonPoints.clear();
        _showQuote = false;
      });
      ref.read(quoteProvider.notifier).state = null;
    }
  }

  Future<void> _orderRide() async {
    if (_pickup == null || _dropoff == null) return;
    final notifier = ref.read(cityRideNotifierProvider.notifier);
    try {
      final ride = await notifier.createRide(
        pickupAddress: _pickupAddress,
        pickupLat: _pickup!.latitude,
        pickupLng: _pickup!.longitude,
        dropoffAddress: _dropoffAddress,
        dropoffLat: _dropoff!.latitude,
        dropoffLng: _dropoff!.longitude,
      );
      if (mounted) {
        context.go('/rides/${ride.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка заказа: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    if (_pickup != null) {
      markers.add(
        Marker(
          point: _pickup!,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.my_location, color: Colors.white, size: 24),
          ),
        ),
      );
    }
    if (_dropoff != null) {
      markers.add(
        Marker(
          point: _dropoff!,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.error,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 24),
          ),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickup ?? _bishkek,
              initialZoom: 14,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'kg.qadam.passenger',
              ),
              PolylineLayer(
                polylines: [
                  if (_polygonPoints.isNotEmpty)
                    Polyline(
                      points: _polygonPoints,
                      color: AppTheme.primary,
                      strokeWidth: 4,
                    ),
                ],
              ),
              MarkerLayer(
                markers: _buildMarkers(),
              ),
            ],
          ),

          // Location loading / error
          if (_loadingLocation)
            const Center(child: CircularProgressIndicator())
          else if (_locationError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.error, size: 48),
                    const SizedBox(height: 8),
                    Text(_locationError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.error)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _initLocation,
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom sheet with route info
          if (_showQuote && _pickup != null && _dropoff != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _RouteBottomSheet(
                pickupAddress: _pickupAddress,
                dropoffAddress: _dropoffAddress,
                onOrder: _orderRide,
                onChangePoints: () {
                  setState(() {
                    _dropoff = null;
                    _dropoffAddress = l10n.whereTo;
                    _polygonPoints.clear();
                    _showQuote = false;
                  });
                },
              ),
            ),

          // Recenter button
          Positioned(
            bottom: _showQuote ? 200 : 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: () {
                if (_pickup != null) {
                  _mapController.move(_pickup!, 15);
                }
              },
              child: const Icon(Icons.my_location, size: 20),
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteBottomSheet extends ConsumerWidget {
  const _RouteBottomSheet({
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.onOrder,
    required this.onChangePoints,
  });

  final String pickupAddress;
  final String dropoffAddress;
  final VoidCallback onOrder;
  final VoidCallback onChangePoints;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final quoteAsync = ref.watch(quoteProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.my_location, color: AppTheme.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.pickupPoint,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                    Text(pickupAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
              if (_pickupChangeButton(context)) ...[],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on, color: AppTheme.error, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.destination,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                    Text(dropoffAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (quoteAsync == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.rideCost,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        '${quoteAsync!.quotedPrice.toStringAsFixed(0)} ${l10n.som}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _InfoChip(
                        icon: Icons.route,
                        label: '${quoteAsync.distanceKm.toStringAsFixed(1)} км'),
                    const SizedBox(height: 4),
                    _InfoChip(
                        icon: Icons.timer,
                        label: '~${quoteAsync.durationMin.toStringAsFixed(0)} мин'),
                  ],
                ),
              ],
            ),
            if (quoteAsync.surgeMultiplier > 1.0) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flash_on,
                        color: AppTheme.warning, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${l10n.surge} ×${quoteAsync.surgeMultiplier.toStringAsFixed(1)}',
                      style: const TextStyle(
                          color: AppTheme.warning,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: QadamButton(
                label: l10n.orderRide,
                onPressed: onOrder,
                icon: Icons.directions_car,
              ),
            ),
            const SizedBox(height: 12),
            QadamButton(
              label: l10n.changeRoute,
              variant: QadamButtonVariant.text,
              onPressed: onChangePoints,
            ),
          ],
        ],
      ),
    );
  }

  bool _pickupChangeButton(BuildContext context) => false;
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary)),
      ],
    );
  }
}
