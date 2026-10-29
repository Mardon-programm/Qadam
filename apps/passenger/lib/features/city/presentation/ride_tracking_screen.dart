import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';
import '../data/city_provider.dart';

const _bishkek = LatLng(42.8746, 74.5698);
const _baseTiles =
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
const _subdomains = ['a', 'b', 'c', 'd'];

class RideTrackingScreen extends ConsumerStatefulWidget {
  const RideTrackingScreen({super.key, required this.rideId});
  final String rideId;

  @override
  ConsumerState<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends ConsumerState<RideTrackingScreen>
    with TickerProviderStateMixin {
  Timer? _pollTimer;
  bool _cancelling = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      ref.read(cityRideNotifierProvider.notifier).refreshRide(widget.rideId);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cityRideNotifierProvider.notifier).refreshRide(widget.rideId);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await ref
          .read(cityRideNotifierProvider.notifier)
          .cancelRide(widget.rideId);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось отменить: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideAsync = ref.watch(cityRideNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: rideAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            _ErrorState(onHome: () => context.go('/home'), error: '$e'),
        data: (ride) {
          if (ride == null) {
            return _ErrorState(
              onHome: () => context.go('/home'),
              title: 'Поездка не найдена',
              error: 'Возможно, она уже завершена или отменена',
            );
          }
          return _RideBody(
            ride: ride,
            pulseCtrl: _pulseCtrl,
            cancelling: _cancelling,
            onCancel: _cancel,
            onHome: () => context.go('/home'),
          );
        },
      ),
    );
  }
}

class _RideBody extends StatelessWidget {
  const _RideBody({
    required this.ride,
    required this.pulseCtrl,
    required this.cancelling,
    required this.onCancel,
    required this.onHome,
  });

  final RideOrder ride;
  final AnimationController pulseCtrl;
  final bool cancelling;
  final VoidCallback onCancel;
  final VoidCallback onHome;

  bool get _isSearching =>
      ride.status == 'created' ||
      ride.status == 'searching' ||
      ride.status == 'offered';

  bool get _isDone => ride.status == 'completed' || ride.status == 'cancelled';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: _bishkek,
              initialZoom: 13,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: _baseTiles,
                subdomains: _subdomains,
                userAgentPackageName: 'kg.qadam.passenger',
              ),
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomRight,
                attributions: [
                  TextSourceAttribution('OpenStreetMap'),
                  TextSourceAttribution('CARTO'),
                ],
              ),
            ],
          ),
        ),
        if (!_isDone)
          Positioned.fill(
            child: IgnorePointer(
              child: _SearchingOverlay(pulseCtrl: pulseCtrl),
            ),
          ),
        Column(
          children: [
            _StatusHeader(ride: ride),
            const Spacer(),
            if (_isDone)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  MediaQuery.of(context).padding.bottom + 16,
                ),
                child: _DoneCard(
                  completed: ride.status == 'completed',
                  price: ride.quotedPrice,
                  onHome: onHome,
                ),
              )
            else
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  MediaQuery.of(context).padding.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSearching) const _SearchingTips(),
                    const SizedBox(height: 10),
                    _DriverRouteCard(ride: ride),
                    const SizedBox(height: 10),
                    QadamActionButton(
                      label: 'Отменить поиск',
                      onTap: onCancel,
                      loading: cancelling,
                      style: QadamButtonStyle.ghost,
                      icon: Icons.close_rounded,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SearchingOverlay extends StatelessWidget {
  const _SearchingOverlay({required this.pulseCtrl});

  final AnimationController pulseCtrl;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: pulseCtrl,
        builder: (_, __) {
          final t = pulseCtrl.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Transform.scale(
                  scale: 1.0 + (t + i * 0.33) % 1.0 * 1.6,
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primary.withValues(
                          alpha: (1.0 - ((t + i * 0.33) % 1.0)) * 0.22,
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.floatShadow,
                ),
                child: const Icon(Icons.local_taxi_rounded,
                    color: Colors.white, size: 42),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchingTips extends StatelessWidget {
  const _SearchingTips();

  @override
  Widget build(BuildContext context) {
    return QadamCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      radius: 18,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppTheme.secondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Ищем ближайших свободных водителей рядом с вами',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.ride});
  final RideOrder ride;

  static const _labels = {
    'created': 'Создаём заказ',
    'searching': 'Ищем водителя',
    'offered': 'Ждём подтверждения',
    'assigned': 'Водитель назначен',
    'driver_arriving': 'Водитель едет к вам',
    'driver_arrived': 'Водитель прибыл',
    'in_progress': 'В пути',
    'completed': 'Поездка завершена',
    'cancelled': 'Поездка отменена',
  };

  static const _subtitles = {
    'created': 'Минуточку, отправляем заказ в ближайших',
    'searching': 'Обычно ответ приходит в течение 30–60 секунд',
    'offered': 'Один из водителей рассматривает ваш заказ',
    'assigned': 'Водитель принял заказ и выезжает',
    'driver_arriving': 'Будьте готовы у указанной точки посадки',
    'driver_arrived': 'Найдите водителя у точки подачи',
    'in_progress': 'Следите за маршрутом и приятной поездки',
    'completed': 'Спасибо, что выбрали Qadam',
    'cancelled': 'Вы всегда можете заказать такси повторно',
  };

  static const _steps = {
    'created': 1,
    'searching': 1,
    'offered': 1,
    'assigned': 2,
    'driver_arriving': 2,
    'driver_arrived': 2,
    'in_progress': 3,
    'completed': 3,
    'cancelled': 3,
  };

  @override
  Widget build(BuildContext context) {
    final status = ride.status;
    final done = status == 'completed' || status == 'cancelled';
    final step = _steps[status] ?? 1;
    final grad =
        status == 'cancelled' ? AppTheme.deepGradient : AppTheme.brandGradient;

    return Container(
      decoration: BoxDecoration(
        gradient: grad,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: AppTheme.floatShadow,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: Stack(
          children: [
            const Positioned.fill(child: QadamOrnament(opacity: 0.12)),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 54),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CircleBack(onTap: () => context.go('/home')),
                        const Spacer(),
                        QadamTag(
                          label: done
                              ? (status == 'completed'
                                  ? 'Завершено'
                                  : 'Отменено')
                              : 'В поиске',
                          color: Colors.white,
                          background: const Color(0x33FFFFFF),
                          icon: done
                              ? (status == 'completed'
                                  ? Icons.check_rounded
                                  : Icons.close_rounded)
                              : Icons.radar_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      _labels[status] ?? status,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white,
                        fontSize: 28,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _subtitles[status] ?? '',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white.withValues(alpha: 0.84),
                        fontSize: 13.5,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!done) ...[
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: QadamStepBar(step: step, total: 3, bright: true),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _Pill(text: '1. Поиск'),
                          const SizedBox(width: 8),
                          _Pill(text: '2. Подъезд'),
                          const SizedBox(width: 8),
                          _Pill(text: '3. Поездка'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _DriverRouteCard extends StatelessWidget {
  const _DriverRouteCard({required this.ride});
  final RideOrder ride;

  @override
  Widget build(BuildContext context) {
    return QadamCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: const BoxDecoration(
                      gradient: AppTheme.brandGradient,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(width: 2, height: 28, color: AppTheme.divider),
                  Container(
                    width: 11,
                    height: 11,
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
                    _AddrRow(label: 'ОТКУДА', value: ride.pickupAddress),
                    const SizedBox(height: 16),
                    _AddrRow(label: 'КУДА', value: ride.dropoffAddress),
                  ],
                ),
              ),
              if (ride.quotedPrice != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${ride.quotedPrice!.toStringAsFixed(0)} сом',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Text(
                      'Ориентир',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddrRow extends StatelessWidget {
  const _AddrRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard(
      {required this.completed, required this.price, required this.onHome});
  final bool completed;
  final double? price;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final color = completed ? AppTheme.success : AppTheme.error;
    return QadamCard(
      radius: 24,
      borderColor: color.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          QadamIconBadge(
            icon:
                completed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 52,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  completed ? 'Поездка завершена' : 'Поездка отменена',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (completed && price != null)
                  Text(
                    'К оплате ${price!.toStringAsFixed(0)} сом · Наличные',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onHome,
            child: const Text(
              'На главную',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState(
      {required this.onHome, this.title = 'Ошибка', required this.error});
  final VoidCallback onHome;
  final String title;
  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: QadamCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const QadamIconBadge(
                  icon: Icons.wifi_off_rounded,
                  color: AppTheme.error,
                  size: 56),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              QadamActionButton(
                label: 'На главную',
                onTap: onHome,
                style: QadamButtonStyle.soft,
                height: 48,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleBack extends StatelessWidget {
  const _CircleBack({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
    );
  }
}
