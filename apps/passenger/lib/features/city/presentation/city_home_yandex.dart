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

const _bishkek = LatLng(42.8746, 74.5698);
const _baseTiles =
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
const _subdomains = ['a', 'b', 'c', 'd'];

class CityHomeScreen extends ConsumerStatefulWidget {
  const CityHomeScreen({super.key});

  @override
  ConsumerState<CityHomeScreen> createState() => _CityHomeScreenState();
}

class _CityHomeScreenState extends ConsumerState<CityHomeScreen> {
  final _mapController = MapController();
  LatLng? _pickup;
  LatLng? _dropoff;
  String _pickupAddress = 'Определяем местоположение...';
  String _dropoffAddress = '';
  bool _loading = true;
  String? _error;
  MapConfig? _mapConfig;
  String _tileUrl = _baseTiles;
  bool _trafficOn = true;
  String _tariff = 'economy';
  StreamSubscription<Position>? _posSub;
  int _reverseId = 0;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _init();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final c = await ref.read(apiServiceProvider).getMapConfig();
      if (mounted) {
        setState(() {
          _mapConfig = c;
          if (c.tileUrlTemplate != null && c.tileUrlTemplate!.isNotEmpty) {
            _tileUrl = c.tileUrlTemplate!;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      var s = await Permission.location.status;
      if (!s.isGranted) s = await Permission.location.request();
      if (!s.isGranted) {
        setState(() {
          _error = 'Включите геолокацию для заказа такси';
          _loading = false;
        });
        return;
      }
      final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10));
      final pos = LatLng(p.latitude, p.longitude);
      if (!mounted) return;
      setState(() {
        _pickup = pos;
        _loading = false;
      });
      _mapController.move(pos, 16);
      _describe(pos, true);
      _posSub = Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high, distanceFilter: 20))
          .listen((x) {
        if (!mounted) return;
        setState(() => _pickup = LatLng(x.latitude, x.longitude));
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  String _coords(LatLng pt) =>
      '${pt.latitude.toStringAsFixed(5)}, ${pt.longitude.toStringAsFixed(5)}';

  Future<void> _describe(LatLng pt, bool isPickup) async {
    final id = ++_reverseId;
    try {
      final place = await ref
          .read(apiServiceProvider)
          .reversePlace(pt.latitude, pt.longitude);
      if (!mounted || id != _reverseId || place == null) return;
      setState(() {
        if (isPickup) {
          _pickupAddress = place.title.isNotEmpty ? place.title : place.fullAddress;
        } else {
          _dropoffAddress = place.title.isNotEmpty ? place.title : place.fullAddress;
        }
      });
    } catch (_) {}
  }

  Future<void> _pick(bool isPickup) async {
    final place = await showPlaceSearch(context,
        title: isPickup ? 'Откуда' : 'Куда', near: _pickup);
    if (place == null || !mounted) return;
    final pt = LatLng(place.lat, place.lng);
    setState(() {
      if (isPickup) {
        _pickup = pt;
        _pickupAddress = place.title.isNotEmpty ? place.title : place.fullAddress;
      } else {
        _dropoff = pt;
        _dropoffAddress = place.title.isNotEmpty ? place.title : place.fullAddress;
      }
    });
    _mapController.move(pt, 16);
    _goQuote();
  }

  Future<void> _goQuote() async {
    if (_pickup == null || _dropoff == null) return;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  bool _ordering = false;

  Future<void> _order() async {
    if (_ordering) return;
    if (_pickup == null || _dropoff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите адрес назначения'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    final quote = ref.read(quoteProvider);
    if (quote == null) {
      _goQuote();
      return;
    }
    setState(() => _ordering = true);
    try {
      final ride = await ref.read(cityRideNotifierProvider.notifier).createRide(
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
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  List<LatLng> _route(RideQuote? q) {
    final g = q?.routeGeometry ?? const [];
    if (g.length >= 2) {
      return g
          .where((p) => p.length >= 2)
          .map((p) => LatLng(p[0], p[1]))
          .toList();
    }
    if (_pickup == null || _dropoff == null) return const [];
    return [_pickup!, _dropoff!];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quote = ref.watch(quoteProvider);
    final route = _route(quote);
    final traffic = quote?.congestion ?? 'unknown';
    final pad = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickup ?? _bishkek,
              initialZoom: 15,
              minZoom: 10,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrl,
                subdomains: _subdomains,
                userAgentPackageName: 'kg.qadam.passenger',
              ),
              PolylineLayer(
                polylines: [
                  if (route.isNotEmpty)
                    Polyline(
                      points: route,
                      color: _trafficOn
                          ? _tc(traffic)
                          : AppTheme.primary,
                      strokeWidth: _trafficOn ? 7 : 6,
                      borderColor: Colors.white,
                      borderStrokeWidth: 3,
                    ),
                ],
              ),
              if (_pickup != null)
                MarkerLayer(markers: [
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
                            shape: BoxShape.circle),
                        child: const Icon(Icons.my_location,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  )
                ]),
              if (_dropoff != null)
                MarkerLayer(markers: [
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
                      child: const Icon(Icons.place_rounded,
                          color: Colors.white, size: 24),
                    ),
                  )
                ]),
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('OpenStreetMap'),
                  TextSourceAttribution('CARTO'),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            top: pad.top + 8,
            child: QadamCard(
              radius: 20,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Row(
                    dot: const _Dot(gradient: AppTheme.brandGradient),
                    label: 'Откуда',
                    value: _pickupAddress,
                    onTap: () => _pick(true),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),
                  _Row(
                    dot: const _Dot(color: AppTheme.ink),
                    label: 'Куда',
                    value: _dropoffAddress.isEmpty ? 'Куда поедем?' : _dropoffAddress,
                    onTap: () => _pick(false),
                    muted: _dropoffAddress.isEmpty,
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
          if (_error != null && _pickup == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: QadamCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const QadamIconBadge(icon: Icons.location_off_rounded, color: AppTheme.error, size: 56),
                      const SizedBox(height: 14),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      QadamActionButton(label: l10n.retry, onTap: _init, style: QadamButtonStyle.soft),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: quote == null
                ? pad.bottom + 16
                : pad.bottom + (route.isNotEmpty ? 280 : 200),
            child: Column(
              children: [
                _Fab(icon: Icons.emergency_rounded, onTap: () => showSosSheet(context)),
                const SizedBox(height: 10),
                _Fab(icon: Icons.traffic_rounded, active: _trafficOn, onTap: () => setState(() => _trafficOn = !_trafficOn)),
                const SizedBox(height: 10),
                _Fab(icon: Icons.my_location_rounded, onTap: () {
                  if (_pickup != null) _mapController.move(_pickup!, 16);
                }),
              ],
            ),
          ),
          if (quote != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: pad.bottom + 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TariffSelector(selectedId: _tariff, onChanged: (v) => setState(() => _tariff = v)),
                  const SizedBox(height: 10),
                  QadamCard(
                    radius: 24,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const QadamIconBadge(icon: Icons.local_taxi_rounded, color: AppTheme.primary, size: 48),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text('Эконом',
                                  style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary)),
                            ),
                            Text(
                              '${quote.quotedPrice.toStringAsFixed(0)} ${l10n.som}',
                              style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _Mini(icon: Icons.route_rounded, text: '${quote.distanceKm.toStringAsFixed(1)} км'),
                            const SizedBox(width: 10),
                            _Mini(icon: Icons.schedule_rounded, text: '~${quote.durationMin.toStringAsFixed(0)} мин'),
                          ],
                        ),
                        const SizedBox(height: 14),
                        QadamActionButton(
                          label: _ordering ? 'Заказываем...' : l10n.orderRide,
                          onTap: _ordering ? null : _order,
                          icon: _ordering ? Icons.hourglass_top_rounded : Icons.arrow_forward_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Color _tc(String c) => switch (c) {
      'heavy' => AppTheme.error,
      'moderate' => AppTheme.warning,
      'free' => AppTheme.success,
      _ => AppTheme.primary,
    };

class _Row extends StatelessWidget {
  const _Row({required this.dot, required this.label, required this.value, required this.onTap, this.muted = false});
  final Widget dot;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          dot,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AppTheme.textSecondary)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: muted ? AppTheme.textSecondary : AppTheme.textPrimary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({this.gradient, this.color});
  final Gradient? gradient;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        gradient: gradient,
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.icon, required this.onTap, this.active = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

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
          decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: AppTheme.floatShadow),
          child: Icon(icon, color: active ? AppTheme.primary : AppTheme.textPrimary),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
