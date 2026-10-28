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

/// CARTO Voyager: readable streets, soft colours, no key required.
const _baseTiles =
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
const _subdomains = ['a', 'b', 'c', 'd'];

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

  String? _selectedOfferId;
  List<LatLng> _approachRoute = const [];
  bool _routeLoading = false;
  Timer? _offersTimer;
  String? _trafficTileUrl;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadOffers();
    _loadTraffic();
    _offersTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      _loadOffers();
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _offersTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTraffic() async {
    try {
      final url = await ref.read(driverApiProvider).getTrafficTileUrl();
      if (mounted) setState(() => _trafficTileUrl = url);
    } catch (_) {}
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
        if (_selectedOfferId != null) _fitToRoute();
      });
    } catch (e) {
      if (mounted) setState(() => _driverPosition = _bishkek);
    }
  }

  Future<void> _loadOffers() async {
    try {
      final api = ref.read(driverApiProvider);
      final offers = await api.getOffers();
      if (!mounted) return;
      final list = List<Map<String, dynamic>>.from(offers);
      setState(() => _loading = false);
      ref.read(offersProvider.notifier).state = list;
      if (_selectedOfferId != null) {
        final stillExists = list.any((o) =>
            o['ride_order_id'] == _selectedOfferId ||
            o['id'] == _selectedOfferId);
        if (!stillExists) {
          setState(() {
            _selectedOfferId = null;
            _approachRoute = const [];
          });
        }
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
        if (newVal == true) {
          _loadOffers();
        } else {
          setState(() {
            _selectedOfferId = null;
            _approachRoute = const [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _selectOffer(Map<String, dynamic> offer) async {
    final rideId = offer['ride_order_id'] as String?;
    if (rideId == null || _driverPosition == null) return;

    final pickupLat = offer['pickup_lat'];
    final pickupLng = offer['pickup_lng'];
    if (pickupLat == null || pickupLng == null) {
      // Fallback: old offers without coords still open the offer screen.
      context.push('/dashboard/offer/$rideId');
      return;
    }

    setState(() {
      _selectedOfferId = rideId;
      _routeLoading = true;
      _approachRoute = const [];
    });

    try {
      final route = await ref.read(driverApiProvider).getRoute(
            fromLat: _driverPosition!.latitude,
            fromLng: _driverPosition!.longitude,
            toLat: (pickupLat as num).toDouble(),
            toLng: (pickupLng as num).toDouble(),
          );
      final geom = route['geometry'] as List?;
      final points = <LatLng>[];
      if (geom != null) {
        for (final p in geom) {
          if (p is List && p.length >= 2) {
            points.add(LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _approachRoute = points;
        _routeLoading = false;
      });
      _fitToRoute();
    } catch (_) {
      if (!mounted) return;
      setState(() => _routeLoading = false);
    }
  }

  void _fitToRoute() {
    final points = <LatLng>[
      if (_driverPosition != null) _driverPosition!,
      ..._approachRoute,
    ];
    if (points.length < 2) return;
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(60, 160, 60, 320),
      ),
    );
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
        setState(() {
          _selectedOfferId = null;
          _approachRoute = const [];
        });
        _loadOffers();
        context.go('/dashboard/ride/$rideOrderId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    if (_driverPosition != null) {
      markers.add(
        Marker(
          point: _driverPosition!,
          width: 56,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              gradient: ref.watch(isOnlineProvider)
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
      );
    }

    final offers = ref.watch(offersProvider);
    final isOnline = ref.watch(isOnlineProvider);
    if (!isOnline) return markers;

    for (final offer in offers) {
      final rideId = offer['ride_order_id'] as String?;
      if (rideId == null) continue;
      final pickupLat = offer['pickup_lat'];
      final pickupLng = offer['pickup_lng'];
      LatLng point;
      if (pickupLat != null && pickupLng != null) {
        point = LatLng((pickupLat as num).toDouble(), (pickupLng as num).toDouble());
      } else {
        final idx = offers.indexOf(offer);
        point = LatLng(
          _bishkek.latitude + (idx % 3) * 0.01 - 0.01,
          _bishkek.longitude + (idx ~/ 3) * 0.01 - 0.01,
        );
      }

      final selected = rideId == _selectedOfferId;
      markers.add(
        Marker(
          point: point,
          width: selected ? 62 : 54,
          height: selected ? 62 : 54,
          child: GestureDetector(
            onTap: () => _selectOffer(offer),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                gradient: selected ? AppTheme.sunGradient : AppTheme.brandGradient,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: selected ? 3 : 2.5),
                boxShadow: AppTheme.floatShadow,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? Icons.navigation_rounded : Icons.location_on_rounded,
                    color: Colors.white,
                    size: selected ? 22 : 19,
                  ),
                  if (!selected)
                    Text(
                      '~${offer['eta_min'] ?? 0}м',
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

  Map<String, dynamic>? _selectedOffer() {
    final offers = ref.read(offersProvider);
    for (final o in offers) {
      if (o['ride_order_id'] == _selectedOfferId) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final offers = ref.watch(offersProvider);
    final selected = _selectedOffer();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _driverPosition ?? _bishkek,
              initialZoom: 14,
              minZoom: 10,
              maxZoom: 18,
              onTap: (_, __) {
                if (_selectedOfferId != null) {
                  setState(() {
                    _selectedOfferId = null;
                    _approachRoute = const [];
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _baseTiles,
                subdomains: _subdomains,
                userAgentPackageName: 'kg.qadam.driver',
              ),
              if (_trafficTileUrl != null && _trafficTileUrl!.isNotEmpty)
                Opacity(
                  opacity: 0.7,
                  child: TileLayer(
                    urlTemplate: _trafficTileUrl,
                    subdomains: const [],
                    userAgentPackageName: 'kg.qadam.driver',
                  ),
                ),
              PolylineLayer(
                polylines: [
                  if (_approachRoute.isNotEmpty)
                    Polyline(
                      points: _approachRoute,
                      color: AppTheme.warning,
                      strokeWidth: 7,
                      borderColor: Colors.white,
                      borderStrokeWidth: 3,
                    ),
                ],
              ),
              MarkerLayer(markers: _buildMarkers()),
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [TextSourceAttribution('OpenStreetMap'), TextSourceAttribution('CARTO')],
              ),
            ],
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

          if (_loading && _driverPosition == null)
            const Center(child: CircularProgressIndicator())
          else if (_error != null && offers.isEmpty && !isOnline)
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

          if (isOnline && offers.isNotEmpty && _selectedOfferId == null)
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
                        'Доступно заказов: ${offers.length} · Нажмите на маркер для выбора',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
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

          if (_selectedOfferId != null && selected != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 14,
              child: _OfferPreviewCard(
                offer: selected,
                loadingRoute: _routeLoading,
                onAccept: () => _acceptOffer(_selectedOfferId!),
                onDetails: () => context.push('/dashboard/offer/$_selectedOfferId'),
                onClose: () {
                  setState(() {
                    _selectedOfferId = null;
                    _approachRoute = const [];
                  });
                },
              ),
            ),

          Positioned(
            bottom: (_selectedOfferId != null) ? 220 : (offers.isNotEmpty && isOnline ? 110 : 24),
            right: 16,
            child: _RoundMapButton(
              icon: Icons.my_location_rounded,
              onTap: () {
                if (_selectedOfferId != null && _approachRoute.isNotEmpty && _driverPosition != null) {
                  _fitToRoute();
                  return;
                }
                if (_driverPosition != null) {
                  _mapController.move(_driverPosition!, 16);
                }
              },
            ),
          ),
        ],
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
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: AppTheme.floatShadow,
          ),
          child: Icon(icon, size: 21, color: AppTheme.primary),
        ),
      ),
    );
  }
}

class _OfferPreviewCard extends StatelessWidget {
  const _OfferPreviewCard({
    required this.offer,
    required this.loadingRoute,
    required this.onAccept,
    required this.onDetails,
    required this.onClose,
  });

  final Map<String, dynamic> offer;
  final bool loadingRoute;
  final VoidCallback onAccept;
  final VoidCallback onDetails;
  final VoidCallback onClose;

  String _addr(dynamic v) => (v as String? ?? '').trim().isEmpty ? '—' : v as String;

  @override
  Widget build(BuildContext context) {
    final net = offer['net_estimate'];
    final eta = offer['eta_min'];
    final price = offer['quoted_price'];
    final dist = offer['distance_km'];

    return QadamSheet(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const QadamIconBadge(
                icon: Icons.route_rounded,
                color: AppTheme.warning,
                size: 44,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Новый заказ · Маршрут к пассажиру',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
                color: AppTheme.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _RouteLine(label: 'Откуда', value: _addr(offer['pickup_address'])),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1, color: AppTheme.divider),
          ),
          _RouteLine(label: 'Куда', value: _addr(offer['dropoff_address'])),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (net != null)
                QadamTag(label: '$net сом · Ваш заработок', color: AppTheme.earningsGreen, background: AppTheme.mint),
              if (price != null)
                QadamTag(label: 'Заказ $price сом', color: AppTheme.primary, background: AppTheme.lavender),
              if (eta != null) QadamTag(label: 'К пассажиру ~$eta мин', color: AppTheme.warning),
              if (dist != null) QadamTag(label: 'Поездка ${dist} км', color: AppTheme.textSecondary),
            ],
          ),
          if (loadingRoute)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text(
                    'Прокладываем маршрут по дорогам...',
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: QadamActionButton(
                  label: 'Подробнее',
                  onTap: onDetails,
                  style: QadamButtonStyle.soft,
                  height: 50,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: QadamActionButton(
                  label: 'Принять заказ',
                  icon: Icons.check_rounded,
                  onTap: onAccept,
                  height: 50,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                gradient: AppTheme.brandGradient,
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 2, height: 24, color: AppTheme.divider),
            Container(
              width: 9,
              height: 9,
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
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13.5,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
