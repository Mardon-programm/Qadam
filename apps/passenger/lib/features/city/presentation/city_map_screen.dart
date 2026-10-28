import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';
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
          _pickupAddress =
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
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
        _pickupAddress =
            '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
      } else if (_dropoff == null) {
        _dropoff = point;
        _dropoffAddress =
            '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
      } else {
        // Both set — tapping again resets dropoff
        _dropoff = point;
        _dropoffAddress =
            '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
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
          SnackBar(
            content: Text('Ошибка заказа: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _resetRoute() {
    setState(() {
      _dropoff = null;
      _dropoffAddress = '';
      _polygonPoints.clear();
      _showQuote = false;
    });
    ref.read(quoteProvider.notifier).state = null;
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    if (_pickup != null) {
      markers.add(
        Marker(
          point: _pickup!,
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppTheme.floatShadow,
            ),
            padding: const EdgeInsets.all(4),
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.my_location,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      );
    }
    if (_dropoff != null) {
      markers.add(
        Marker(
          point: _dropoff!,
          width: 48,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.ink,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: AppTheme.floatShadow,
            ),
            child: const Icon(
              Icons.flag_rounded,
              color: Colors.white,
              size: 20,
            ),
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
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          // Map, desaturated a little so the brand overlays read clearly.
          ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.86, 0.08, 0.06, 0, 6,
              0.06, 0.88, 0.06, 0, 6,
              0.06, 0.08, 0.86, 0, 6,
              0, 0, 0, 1, 0,
            ]),
            child: FlutterMap(
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
                        strokeWidth: 5,
                        borderColor: Colors.white,
                        borderStrokeWidth: 2,
                      ),
                  ],
                ),
                MarkerLayer(markers: _buildMarkers()),
              ],
            ),
          ),

          // Location loading / error
          if (_loadingLocation)
            const Center(
              child: QadamCard(
                padding: EdgeInsets.all(24),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                ),
              ),
            )
          else if (_locationError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: QadamCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const QadamIconBadge(
                        icon: Icons.location_off_rounded,
                        color: AppTheme.error,
                        size: 56,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _locationError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      QadamActionButton(
                        label: l10n.retry,
                        onTap: _initLocation,
                        style: QadamButtonStyle.soft,
                        height: 48,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Route card
          Positioned(
            left: 16,
            right: 16,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: QadamCard(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  radius: 22,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              gradient: AppTheme.brandGradient,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 2,
                            height: 26,
                            color: AppTheme.divider,
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppTheme.ink,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _RouteLine(
                              label: l10n.pickupPoint,
                              value: _pickupAddress.isEmpty
                                  ? '—'
                                  : _pickupAddress,
                            ),
                            const SizedBox(height: 14),
                            _RouteLine(
                              label: l10n.destination,
                              value: _dropoff == null
                                  ? 'Нажмите на карту'
                                  : _dropoffAddress,
                              muted: _dropoff == null,
                            ),
                          ],
                        ),
                      ),
                      if (_dropoff != null)
                        IconButton(
                          onPressed: _resetRoute,
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: AppTheme.textSecondary,
                        ),
                    ],
                  ),
                ),
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
                onChangePoints: _resetRoute,
              ),
            ),

          // Recenter button
          Positioned(
            bottom: _showQuote ? 320 : 24,
            right: 16,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 0,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  if (_pickup != null) {
                    _mapController.move(_pickup!, 15);
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.floatShadow,
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    size: 20,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.label,
    required this.value,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: muted ? AppTheme.textSecondary : AppTheme.textPrimary,
          ),
        ),
      ],
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

    return QadamSheet(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.lavender,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.local_taxi_rounded,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Qadam City',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Ближайший водитель · ~5 мин',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              QadamTag(
                label: l10n.som,
                color: AppTheme.secondary,
                icon: Icons.payments_rounded,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (quoteAsync == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.rideCost.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${quoteAsync.quotedPrice.toStringAsFixed(0)} ${l10n.som}',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                          height: 1.05,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _MetricPill(
                      icon: Icons.route_rounded,
                      value: '${quoteAsync.distanceKm.toStringAsFixed(1)} км',
                    ),
                    const SizedBox(width: 8),
                    _MetricPill(
                      icon: Icons.schedule_rounded,
                      value: '~${quoteAsync.durationMin.toStringAsFixed(0)} мин',
                    ),
                  ],
                ),
              ],
            ),
            if (quoteAsync.surgeMultiplier > 1.0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  QadamTag(
                    label:
                        '${l10n.surge} ×${quoteAsync.surgeMultiplier.toStringAsFixed(1)}',
                    color: AppTheme.warning,
                    icon: Icons.bolt_rounded,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            QadamActionButton(
              label: l10n.orderRide,
              onTap: onOrder,
              icon: Icons.arrow_forward_rounded,
            ),
            const SizedBox(height: 8),
            QadamActionButton(
              label: l10n.changeRoute,
              onTap: onChangePoints,
              style: QadamButtonStyle.link,
              height: 44,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
