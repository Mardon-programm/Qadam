import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';
import '../data/city_provider.dart';

class RideTrackingScreen extends ConsumerStatefulWidget {
  const RideTrackingScreen({super.key, required this.rideId});
  final String rideId;

  @override
  ConsumerState<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends ConsumerState<RideTrackingScreen> {
  Timer? _pollTimer;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    // Poll ride status every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.read(cityRideNotifierProvider.notifier).refreshRide(widget.rideId);
    });
    // Initial fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cityRideNotifierProvider.notifier).refreshRide(widget.rideId);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await ref
          .read(cityRideNotifierProvider.notifier)
          .cancelRide(widget.rideId);
      if (mounted) context.go('/home');
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
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: QadamCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const QadamIconBadge(
                    icon: Icons.wifi_off_rounded,
                    color: AppTheme.error,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ошибка: $e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  QadamActionButton(
                    label: 'На главную',
                    onTap: () => context.go('/home'),
                    style: QadamButtonStyle.soft,
                    height: 48,
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (ride) {
          if (ride == null) {
            return const Center(
              child: Text(
                'Поездка не найдена',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            );
          }

          final isCompleted = ride.status == 'completed';
          final isCancelled = ride.status == 'cancelled';
          final isDone = isCompleted || isCancelled;

          return Column(
            children: [
              _StatusHeader(
                status: ride.status,
                price: ride.quotedPrice,
                eta: ride.etaMin,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -28),
                      child: Column(
                        children: [
                          _RouteCard(
                            pickup: ride.pickupAddress,
                            dropoff: ride.dropoffAddress,
                          ),
                          const SizedBox(height: 14),
                          if (!isDone) const _LiveHint(),
                          if (isDone)
                            _DoneCard(
                              completed: isCompleted,
                              price: ride.quotedPrice,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  MediaQuery.of(context).padding.bottom + 20,
                ),
                child: isDone
                    ? QadamActionButton(
                        label: 'На главную',
                        onTap: () => context.go('/home'),
                        icon: Icons.home_rounded,
                      )
                    : QadamActionButton(
                        label: 'Отменить поездку',
                        onTap: _cancel,
                        loading: _cancelling,
                        style: QadamButtonStyle.ghost,
                        icon: Icons.close_rounded,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({
    required this.status,
    required this.price,
    required this.eta,
  });

  final String status;
  final double? price;
  final int? eta;

  static const _labels = {
    'created': 'Создан',
    'searching': 'Ищем водителя…',
    'offered': 'Ожидаем ответа водителя',
    'assigned': 'Водитель назначен',
    'driver_arriving': 'Водитель едет к вам',
    'driver_arrived': 'Водитель прибыл',
    'in_progress': 'В пути',
    'completed': 'Завершено',
    'cancelled': 'Отменено',
  };

  static const _subtitles = {
    'created': 'Подбираем ближайший автомобиль',
    'searching': 'Обычно это занимает меньше минуты',
    'offered': 'Водитель вот-вот подтвердит заказ',
    'assigned': 'Машина уже выехала',
    'driver_arriving': 'Ожидайте у точки подачи',
    'driver_arrived': 'Водитель ждёт вас',
    'in_progress': 'Хорошей дороги!',
    'completed': 'Спасибо, что выбрали Qadam',
    'cancelled': 'Поездка отменена',
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
  };

  @override
  Widget build(BuildContext context) {
    final completed = status == 'completed';
    final cancelled = status == 'cancelled';
    final step = _steps[status] ?? 1;

    return Container(
      decoration: BoxDecoration(
        gradient: cancelled ? AppTheme.deepGradient : AppTheme.brandGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
        boxShadow: AppTheme.floatShadow,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
        child: Stack(
          children: [
            const Positioned.fill(child: QadamOrnament(opacity: 0.14)),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CircleBack(onTap: () => context.go('/home')),
                        const Spacer(),
                        if (completed)
                          const QadamTag(
                            label: 'Завершено',
                            color: Colors.white,
                            background: Color(0x33FFFFFF),
                            icon: Icons.check_rounded,
                          )
                        else if (cancelled)
                          const QadamTag(
                            label: 'Отменено',
                            color: Colors.white,
                            background: Color(0x33FFFFFF),
                            icon: Icons.close_rounded,
                          )
                        else
                          const QadamTag(
                            label: 'LIVE',
                            color: Colors.white,
                            background: Color(0x33FFFFFF),
                            icon: Icons.bolt_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _labels[status] ?? status,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _subtitles[status] ?? '',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!completed && !cancelled) ...[
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: QadamStepBar(
                          step: step,
                          total: 3,
                          bright: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _HeaderStat(
                          label: 'Стоимость',
                          value: price != null
                              ? '${price!.toStringAsFixed(0)} сом'
                              : '—',
                        ),
                        const SizedBox(width: 32),
                        _HeaderStat(
                          label: 'Ожидание',
                          value: eta != null ? '~$eta мин' : '—',
                        ),
                      ],
                    ),
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

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: Colors.white,
          ),
        ),
      ],
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
          width: 44,
          height: 44,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 19,
          ),
        ),
      ),
    );
  }
}

// ── Body cards ──────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.pickup, required this.dropoff});
  final String pickup;
  final String dropoff;

  @override
  Widget build(BuildContext context) {
    return QadamCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      gradient: AppTheme.brandGradient,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(width: 2, height: 34, color: AppTheme.divider),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppTheme.ink,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Address(
                      label: 'Откуда',
                      value: pickup,
                    ),
                    const SizedBox(height: 22),
                    _Address(
                      label: 'Куда',
                      value: dropoff,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Address extends StatelessWidget {
  const _Address({required this.label, required this.value});
  final String label;
  final String value;

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
            letterSpacing: 1.2,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 15,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _LiveHint extends StatelessWidget {
  const _LiveHint();

  @override
  Widget build(BuildContext context) {
    return QadamCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const QadamIconBadge(
            icon: Icons.notifications_active_rounded,
            size: 44,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Экран обновляется автоматически — можно не обновлять вручную',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.secondary,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.completed, required this.price});
  final bool completed;
  final double? price;

  @override
  Widget build(BuildContext context) {
    final color = completed ? AppTheme.success : AppTheme.error;
    return QadamCard(
      borderColor: color.withValues(alpha: 0.3),
      child: Row(
        children: [
          QadamIconBadge(
            icon: completed
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
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
                if (completed && price != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Оплачено ${price!.toStringAsFixed(0)} сом',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
