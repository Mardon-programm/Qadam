import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/api/api_service.dart';
import '../../../core/api/models.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';
import '../data/city_provider.dart';
import 'place_search_sheet.dart';
import 'tariff_selector.dart';
import 'sos_sheet.dart';

// Default centre: Bishkek
const _bishkek = LatLng(42.8746, 74.5698);

/// CARTO Voyager: readable streets, soft colours, no key required.
const _baseTiles =
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
const _subdomains = ['a', 'b', 'c', 'd'];

class CityMapScreen extends ConsumerStatefulWidget {
  const CityMapScreen({super.key});

  @override
  ConsumerState<CityMapScreen> createState() => _CityMapScreenState();
}

class _CityMapScreenState extends ConsumerState<CityMapScreen> {
  final _mapController = MapController();

  LatLng? _pickup;
  LatLng? _dropoff;
  String _pickupAddress = '';
  String _dropoffAddress = '';
  bool _loadingLocation = true;
  String? _locationError;
  bool _showQuote = false;

  MapConfig? _mapConfig;
  bool _trafficOn = true;
  bool _followUser = true;
  String _tariff = 'economy';

  StreamSubscription<Position>? _positionStream;
  DateTime _lastQuoteAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _reverseId = 0;

  @override
  void initState() {
    super.initState();
    _loadMapConfig();
    _initLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _loadMapConfig() async {
    try {
      final config = await ref.read(apiServiceProvider).getMapConfig();
      if (mounted) setState(() => _mapConfig = config);
    } catch (_) {
      // Traffic is optional; the map works without it.
    }
  }

  Future<void> _initLocation() async {
    setState(() => _loadingLocation = true);
    try {
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
      if (!mounted) return;

      setState(() {
        _pickup = pos;
        _pickupAddress = _coords(pos);
        _loadingLocation = false;
      });
      _mapController.move(pos, 15);
      _describe(pos, isPickup: true);

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      ).listen((p) {
        if (!mounted || !_followUser) return;
        final next = LatLng(p.latitude, p.longitude);
        setState(() => _pickup = next);
        _updateRoute();
      });
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

  static String _coords(LatLng point) =>
      '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';

  static String _label(PlaceSuggestion place) {
    final title = place.title;
    if (title.isEmpty) return place.fullAddress;
    return title;
  }

  Future<void> _describe(LatLng point, {required bool isPickup}) async {
    final id = ++_reverseId;
    try {
      final place =
          await ref.read(apiServiceProvider).reversePlace(point.latitude, point.longitude);
      if (!mounted || id != _reverseId) return;
      if (place == null) return;
      setState(() {
        if (isPickup) {
          _pickupAddress = _label(place);
        } else {
          _dropoffAddress = _label(place);
        }
      });
      _updateRoute(force: true);
    } catch (_) {
      // Keep the coordinate label if reverse geocoding failed.
    }
  }

  void _setDropoff(LatLng point, {String? address}) {
    setState(() {
      _dropoff = point;
      _dropoffAddress = address ?? _coords(point);
    });
    _updateRoute();
    if (address == null) _describe(point, isPickup: false);
  }

  void _onMapTap(TapPosition _, LatLng point) {
    if (_pickup == null) {
      setState(() {
        _pickup = point;
        _pickupAddress = _coords(point);
      });
      _describe(point, isPickup: true);
      return;
    }
    _setDropoff(point);
  }

  Future<void> _pickPlace({required bool isPickup}) async {
    final place = await showPlaceSearch(
      context,
      title: isPickup ? 'Откуда поедем' : 'Куда едем',
      near: _pickup,
    );
    if (place == null || !mounted) return;
    final point = LatLng(place.lat, place.lng);
    if (isPickup) {
      _followUser = false;
      _positionStream?.cancel();
    }
    setState(() {
      if (isPickup) {
        _pickup = point;
        _pickupAddress = _label(place);
      } else {
        _dropoff = point;
        _dropoffAddress = _label(place);
      }
    });
    _mapController.move(point, isPickup ? 15 : _mapController.camera.zoom);
    _updateRoute(force: true);
  }

  Future<void> _updateRoute({bool force = false}) async {
    if (_pickup == null || _dropoff == null) {
      setState(() => _showQuote = false);
      ref.read(quoteProvider.notifier).state = null;
      return;
    }

    setState(() => _showQuote = true);

    final now = DateTime.now();
    if (!force && now.difference(_lastQuoteAt) < const Duration(seconds: 5)) {
      return;
    }
    _lastQuoteAt = now;
    ref.read(quoteProvider.notifier).state = null;
    try {
      await ref.read(cityRideNotifierProvider.notifier).quote(
            pickupAddress: _pickupAddress,
            pickupLat: _pickup!.latitude,
            pickupLng: _pickup!.longitude,
            dropoffAddress: _dropoffAddress,
            dropoffLat: _dropoff!.latitude,
            dropoffLng: _dropoff!.longitude,
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
      if (mounted) context.go('/rides/${ride.id}');
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
      _showQuote = false;
    });
    ref.read(quoteProvider.notifier).state = null;
  }

  List<LatLng> _routePoints(RideQuote? quote) {
    final geometry = quote?.routeGeometry ?? const [];
    if (geometry.length >= 2) {
      return geometry
          .where((p) => p.length >= 2)
          .map((p) => LatLng(p[0], p[1]))
          .toList();
    }
    if (_pickup == null || _dropoff == null) return const [];
    // Visual fallback only — production quotes always carry a road geometry.
    return [_pickup!, _dropoff!];
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
              child: const Icon(Icons.my_location, color: Colors.white, size: 18),
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
            child: const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
          ),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quote = ref.watch(quoteProvider);
    final route = _routePoints(quote);
    final traffic = quote?.congestion ?? 'unknown';

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickup ?? _bishkek,
              initialZoom: 14,
              minZoom: 10,
              maxZoom: 18,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: _baseTiles,
                subdomains: _subdomains,
                userAgentPackageName: 'kg.qadam.passenger',
              ),
              PolylineLayer(
                polylines: [
                  if (route.isNotEmpty && _trafficOn)
                    Polyline(
                      points: route,
                      color: _trafficColor(traffic),
                      strokeWidth: 7,
                      borderColor: Colors.white,
                      borderStrokeWidth: 3,
                    ),
                  if (route.isNotEmpty && !_trafficOn)
                    Polyline(
                      points: route,
                      color: AppTheme.primary,
                      strokeWidth: 6,
                      borderColor: Colors.white,
                      borderStrokeWidth: 3,
                    ),
                ],
              ),
              MarkerLayer(markers: _buildMarkers()),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('OpenStreetMap'),
                  if (!_trafficOn) TextSourceAttribution('CARTO'),
                ],
              ),
            ],
          ),

          // Address card
          Positioned(
            left: 16,
            right: 16,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _AddressCard(
                  pickup: _pickupAddress,
                  dropoff: _dropoffAddress,
                  hasDropoff: _dropoff != null,
                  onPickup: () => _pickPlace(isPickup: true),
                  onDropoff: () => _pickPlace(isPickup: false),
                  onClear: _resetRoute,
                ),
              ),
            ),
          ),

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

          // Controls + quote live in one bottom column so they can never
          // overlap each other, whatever the sheet height is.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _MapChip(
                          icon: Icons.traffic_rounded,
                          label: 'Пробки',
                          active: _trafficOn,
                          onTap: () =>
                              setState(() => _trafficOn = !_trafficOn),
                        ),
                        const SizedBox(width: 10),
                        _RoundMapButton(
                          icon: Icons.emergency_rounded,
                          onTap: () => showSosSheet(context),
                        ),
                        const SizedBox(width: 10),
                        _RoundMapButton(
                          icon: Icons.my_location_rounded,
                          onTap: () {
                            if (_pickup != null) {
                              _mapController.move(_pickup!, 15);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  if (_trafficOn && _showQuote) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _TrafficLegend(congestion: traffic),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (_showQuote && _pickup != null && _dropoff != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TariffSelector(
                        selectedId: _tariff,
                        onChanged: (v) => setState(() => _tariff = v),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _RouteBottomSheet(
                      pickupAddress: _pickupAddress,
                      dropoffAddress: _dropoffAddress,
                      onOrder: _orderRide,
                      onChangePoints: _resetRoute,
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _trafficColor(String congestion) {
  return switch (congestion) {
    'heavy' => AppTheme.error,
    'moderate' => AppTheme.warning,
    'free' => AppTheme.success,
    _ => AppTheme.primary,
  };
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.pickup,
    required this.dropoff,
    required this.hasDropoff,
    required this.onPickup,
    required this.onDropoff,
    required this.onClear,
  });

  final String pickup;
  final String dropoff;
  final bool hasDropoff;
  final VoidCallback onPickup;
  final VoidCallback onDropoff;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return QadamCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
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
              Container(width: 2, height: 30, color: AppTheme.divider),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                _PlaceRow(
                  label: 'ОТКУДА',
                  value: pickup.isEmpty ? 'Моё местоположение' : pickup,
                  onTap: onPickup,
                ),
                const SizedBox(height: 10),
                _PlaceRow(
                  label: 'КУДА',
                  value: hasDropoff ? dropoff : 'Выберите адрес или точку на карте',
                  muted: !hasDropoff,
                  onTap: onDropoff,
                ),
              ],
            ),
          ),
          if (hasDropoff)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 20),
              color: AppTheme.textSecondary,
              visualDensity: VisualDensity.compact,
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.muted = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: muted ? AppTheme.textSecondary : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: active ? AppTheme.brandGradient : null,
            color: active ? null : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppTheme.floatShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: active ? Colors.white : AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundMapButton extends StatelessWidget {
  const _RoundMapButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: AppTheme.floatShadow,
          ),
          child: Icon(icon, size: 20, color: AppTheme.primary),
        ),
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
    final quote = ref.watch(quoteProvider);

    return QadamSheet(
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const QadamIconBadge(
                icon: Icons.local_taxi_rounded,
                color: AppTheme.primary,
                size: 44,
              ),
              const SizedBox(width: 12),
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
                      'Без комиссии для водителя',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (quote != null)
                _TrafficBadge(congestion: quote.congestion),
            ],
          ),
          const SizedBox(height: 14),
          if (quote == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
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
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${quote.quotedPrice.toStringAsFixed(0)} ${l10n.som}',
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
                      value: '${quote.distanceKm.toStringAsFixed(1)} км',
                    ),
                    const SizedBox(width: 8),
                    _MetricPill(
                      icon: Icons.schedule_rounded,
                      value: '~${quote.durationMin.toStringAsFixed(0)} мин',
                    ),
                  ],
                ),
              ],
            ),
            if (quote.surgeMultiplier > 1.01) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (quote.demandMultiplier > 1.01)
                    QadamTag(
                      label: 'Спрос ×${quote.demandMultiplier.toStringAsFixed(1)}',
                      color: AppTheme.warning,
                      icon: Icons.people_alt_rounded,
                    ),
                  if (quote.trafficMultiplier > 1.01)
                    QadamTag(
                      label: 'Пробки ×${quote.trafficMultiplier.toStringAsFixed(1)}',
                      color: _trafficColor(quote.congestion),
                      icon: Icons.traffic_rounded,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _FareBreakdown(quote: quote),
            const SizedBox(height: 14),
            QadamActionButton(
              label: l10n.orderRide,
              onTap: onOrder,
              icon: Icons.arrow_forward_rounded,
            ),
            const SizedBox(height: 4),
            QadamActionButton(
              label: l10n.changeRoute,
              onTap: onChangePoints,
              style: QadamButtonStyle.link,
              height: 40,
            ),
            if (quote.routeSource == 'estimate')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Маршрут построен приблизительно',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _FareBreakdown extends StatelessWidget {
  const _FareBreakdown({required this.quote});

  final RideQuote quote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Тариф: 50 сом + 12 сом/км + 2 сом/мин · водитель получает 100%',
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11.5,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrafficBadge extends StatelessWidget {
  const _TrafficBadge({required this.congestion});

  final String congestion;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (congestion) {
      'heavy' => ('Пробки', Icons.traffic_rounded),
      'moderate' => ('Средний трафик', Icons.speed_rounded),
      'free' => ('Свободно', Icons.bolt_rounded),
      _ => ('Маршрут', Icons.alt_route_rounded),
    };
    return QadamTag(
      label: label,
      color: _trafficColor(congestion),
      icon: icon,
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}


class _TrafficLegend extends StatelessWidget {
  const _TrafficLegend({required this.congestion});

  final String congestion;

  @override
  Widget build(BuildContext context) {
    final color = _trafficColor(congestion);
    final label = switch (congestion) {
      'heavy' => 'Затруднено',
      'moderate' => 'Средне',
      'free' => 'Свободно',
      _ => 'По пробкам',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.floatShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
