import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

/// Driver-side screen for an accepted ride: start and complete it.
class ActiveRideScreen extends ConsumerStatefulWidget {
  const ActiveRideScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen> {
  Map<String, dynamic>? _ride;
  bool _loading = true;
  bool _busy = false;
  Timer? _poll;
  Timer? _locTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
    _locTimer = Timer.periodic(const Duration(seconds: 8), (_) => _sendLocation());
    _sendLocation();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _locTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      await ref.read(driverApiProvider).updateLocation(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final ride = await ref.read(driverApiProvider).getRide(widget.rideId);
      if (mounted) {
        setState(() {
          _ride = ride;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        debugPrint('ACTIVE RIDE LOAD ERROR: $e');
      }
    }
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final ride = await ref.read(driverApiProvider).startRide(widget.rideId);
      if (mounted) setState(() => _ride = ride);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    setState(() => _busy = true);
    try {
      final ride = await ref.read(driverApiProvider).completeRide(widget.rideId);
      if (!mounted) return;
      setState(() => _ride = ride);
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: QadamCard(
            radius: 28,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Поездка завершена',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ваш заработок: ${_formatMoney(ride['driver_net_estimate'])}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                QadamActionButton(
                  label: 'Готово',
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        ),
      );
      if (mounted) context.go('/dashboard');
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$e')));
  }

  String _formatMoney(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed == null) return '—';
    return '${parsed.toStringAsFixed(0)} сом';
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'assigned':
        return 'Заказ принят';
      case 'driver_arriving':
        return 'В пути к пассажиру';
      case 'driver_arrived':
        return 'Вы на месте';
      case 'in_progress':
        return 'Поездка идёт';
      case 'completed':
        return 'Поездка завершена';
      case 'cancelled':
        return 'Поездка отменена';
      default:
        return 'Текущая поездка';
    }
  }

  String _statusHint(String? status) {
    switch (status) {
      case 'assigned':
        return 'Едьте к точке посадки';
      case 'driver_arriving':
        return 'Пассажир ждёт вас';
      case 'driver_arrived':
        return 'Заберите пассажира';
      case 'in_progress':
        return 'Завершите поездку на месте назначения';
      default:
        return 'Детали заказа ниже';
    }
  }

  int _step(String? status) {
    switch (status) {
      case 'assigned':
      case 'driver_arriving':
        return 1;
      case 'driver_arrived':
        return 2;
      case 'in_progress':
        return 3;
      case 'completed':
        return 3;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = _ride;
    final status = ride?['status'] as String?;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ride == null
              ? const Center(
                  child: Text(
                    'Поездка не найдена',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              : Column(
                  children: [
                    _RideHeader(
                      statusLabel: _statusLabel(status),
                      hint: _statusHint(status),
                      step: _step(status),
                      price: _formatMoney(ride['quoted_price']),
                      net: _formatMoney(ride['driver_net_estimate']),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [
                          Transform.translate(
                            offset: const Offset(0, -30),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                QadamCard(
                                  radius: 26,
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      _AddressRow(
                                        dotColor: null,
                                        title: 'Откуда',
                                        value: ride['pickup_address']
                                                ?.toString() ??
                                            '—',
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 5),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 2,
                                              height: 26,
                                              color: AppTheme.divider,
                                            ),
                                          ],
                                        ),
                                      ),
                                      _AddressRow(
                                        dotColor: AppTheme.ink,
                                        title: 'Куда',
                                        value: ride['dropoff_address']
                                                ?.toString() ??
                                            '—',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const _PaymentHint(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        MediaQuery.of(context).padding.bottom + 16,
                      ),
                      child: status == 'assigned' || status == 'driver_arrived'
                          ? QadamActionButton(
                              label: status == 'assigned'
                                  ? 'Начать поездку'
                                  : 'Начать поездку',
                              onTap: _busy ? null : _start,
                              loading: _busy,
                              icon: Icons.play_arrow_rounded,
                            )
                          : status == 'in_progress'
                              ? QadamActionButton(
                                  label: 'Завершить поездку',
                                  onTap: _busy ? null : _complete,
                                  loading: _busy,
                                  icon: Icons.flag_rounded,
                                )
                              : QadamActionButton(
                                  label: 'На главную',
                                  onTap: () => context.go('/dashboard'),
                                  icon: Icons.home_rounded,
                                ),
                    ),
                  ],
                ),
    );
  }
}

class _RideHeader extends StatelessWidget {
  const _RideHeader({
    required this.statusLabel,
    required this.hint,
    required this.step,
    required this.price,
    required this.net,
  });

  final String statusLabel;
  final String hint;
  final int step;
  final String price;
  final String net;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
        child: Stack(
          children: [
            const Positioned.fill(child: QadamOrnament(opacity: 0.16)),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 52),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Material(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => context.go('/dashboard'),
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
                        ),
                        const Spacer(),
                        const QadamTag(
                          label: 'В ПОЕЗДКЕ',
                          color: Colors.white,
                          background: Color(0x33FFFFFF),
                          icon: Icons.local_taxi_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text(
                      statusLabel,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white,
                        fontSize: 28,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hint,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    QadamStepBar(step: step, total: 3, bright: true),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _HeaderStat(label: 'Стоимость', value: price),
                        const SizedBox(width: 32),
                        _HeaderStat(label: 'Вам', value: net),
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

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.dotColor,
    required this.title,
    required this.value,
  });

  final Color? dotColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            gradient: dotColor == null ? AppTheme.brandGradient : null,
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentHint extends StatelessWidget {
  const _PaymentHint();

  @override
  Widget build(BuildContext context) {
    return QadamCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      color: AppTheme.mint,
      borderColor: Colors.transparent,
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.payments_rounded, color: AppTheme.success, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Возьмите оплату у пассажира наличными или переводом. Комиссия Qadam — 0%.',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppTheme.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
