import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_button.dart';
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
      appBar: AppBar(
        title: const Text('Отслеживание поездки'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: rideAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (ride) {
          if (ride == null) {
            return const Center(child: Text('Поездка не найдена'));
          }

          final isCompleted = ride.status == 'completed';
          final isCancelled = ride.status == 'cancelled';
          final isDone = isCompleted || isCancelled;

          return Column(
            children: [
              // Status card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _StatusIndicator(status: ride.status),
                    const SizedBox(height: 20),
                    _RouteRow(
                      pickup: ride.pickupAddress,
                      dropoff: ride.dropoffAddress,
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _DetailCell(
                          label: 'Стоимость',
                          value: ride.quotedPrice != null
                              ? '${ride.quotedPrice!.toStringAsFixed(0)} сом'
                              : '—',
                        ),
                        if (ride.etaMin != null)
                          _DetailCell(
                            label: 'Водитель',
                            value: '~${ride.etaMin} мин',
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Actions
              Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 0, 16, MediaQuery.of(context).padding.bottom + 24),
                child: Column(
                  children: [
                    if (isDone) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppTheme.secondary.withOpacity(0.1)
                              : AppTheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isCompleted ? Icons.check_circle : Icons.cancel,
                              color: isCompleted
                                  ? AppTheme.secondary
                                  : AppTheme.error,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isCompleted
                                  ? 'Поездка завершена'
                                  : 'Поездка отменена',
                              style: TextStyle(
                                color: isCompleted
                                    ? AppTheme.secondary
                                    : AppTheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      QadamButton(
                        label: 'На главную',
                        onPressed: () => context.go('/home'),
                      ),
                    ] else
                      QadamButton(
                        label: 'Отменить поездку',
                        variant: QadamButtonVariant.outline,
                        isLoading: _cancelling,
                        onPressed: _cancel,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});
  final String status;

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

  static const _colors = {
    'searching': AppTheme.warning,
    'offered': AppTheme.warning,
    'assigned': AppTheme.primary,
    'driver_arriving': AppTheme.primary,
    'driver_arrived': AppTheme.secondary,
    'in_progress': AppTheme.secondary,
    'completed': AppTheme.secondary,
    'cancelled': AppTheme.error,
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[status] ?? status;
    final color = _colors[status] ?? AppTheme.textSecondary;

    return Row(
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
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 15)),
      ],
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.pickup, required this.dropoff});
  final String pickup;
  final String dropoff;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.my_location, color: AppTheme.primary, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(pickup,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on, color: AppTheme.error, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(dropoff,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailCell extends StatelessWidget {
  const _DetailCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
