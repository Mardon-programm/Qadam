import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
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
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: AppTheme.secondary, size: 48),
          title: const Text('Поездка завершена'),
          content: Text(
            'Ваш заработок: ${_formatMoney(ride['driver_net_estimate'])}',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Готово'),
            ),
          ],
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
        return 'Заказ принят — едьте к пассажиру';
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
        return 'Заказ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = _ride;
    final status = ride?['status'] as String?;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Текущая поездка'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ride == null
              ? const Center(child: Text('Поездка не найдена'))
              : Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            AppTheme.primary,
                            Color(0xFF1D4ED8),
                          ]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _statusLabel(status),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_formatMoney(ride['quoted_price'])} · ${_formatMoney(ride['driver_net_estimate'])} вам',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _AddressTile(
                        icon: Icons.my_location,
                        color: AppTheme.primary,
                        title: 'Откуда',
                        value: ride['pickup_address']?.toString() ?? '—',
                      ),
                      const SizedBox(height: 8),
                      _AddressTile(
                        icon: Icons.location_on,
                        color: AppTheme.error,
                        title: 'Куда',
                        value: ride['dropoff_address']?.toString() ?? '—',
                      ),
                      const Spacer(),
                      if (status == 'assigned')
                        _PrimaryButton(
                          label: 'Начать поездку',
                          onPressed: _busy ? null : _start,
                          isLoading: _busy,
                        )
                      else if (status == 'in_progress')
                        _PrimaryButton(
                          label: 'Завершить поездку',
                          onPressed: _busy ? null : _complete,
                          isLoading: _busy,
                          color: AppTheme.secondary,
                        )
                      else
                        _PrimaryButton(
                          label: 'На главную',
                          onPressed: () => context.go('/dashboard'),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.color = AppTheme.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
