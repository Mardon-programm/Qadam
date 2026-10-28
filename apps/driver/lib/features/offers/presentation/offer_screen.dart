import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

class OfferScreen extends ConsumerStatefulWidget {
  const OfferScreen({super.key, required this.rideId});
  final String rideId;

  @override
  ConsumerState<OfferScreen> createState() => _OfferScreenState();
}

class _OfferScreenState extends ConsumerState<OfferScreen> {
  Map<String, dynamic>? _ride;
  bool _loading = true;
  bool _accepting = false;
  bool _declining = false;

  @override
  void initState() {
    super.initState();
    _loadRide();
  }

  Future<void> _loadRide() async {
    try {
      final api = ref.read(driverApiProvider);
      final ride = await api.getRide(widget.rideId);
      if (mounted) {
        setState(() {
          _ride = ride;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      final api = ref.read(driverApiProvider);
      await api.acceptRide(widget.rideId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заказ принят! Едьте к пассажиру.'),
            backgroundColor: AppTheme.secondary,
          ),
        );
        context.go('/dashboard/ride/${widget.rideId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _declining = true);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ride == null
              ? const Center(
                  child: Text(
                    'Заказ не найден',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              : _RideOfferDetails(
                  ride: _ride!,
                  accepting: _accepting,
                  declining: _declining,
                  onAccept: _accept,
                  onDecline: _decline,
                ),
    );
  }
}

class _RideOfferDetails extends StatelessWidget {
  const _RideOfferDetails({
    required this.ride,
    required this.accepting,
    required this.declining,
    required this.onAccept,
    required this.onDecline,
  });

  final Map<String, dynamic> ride;
  final bool accepting;
  final bool declining;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  double? get _net => ride['driver_net_estimate'] != null
      ? double.tryParse(ride['driver_net_estimate'].toString())
      : null;

  double? get _price => ride['quoted_price'] != null
      ? double.tryParse(ride['quoted_price'].toString())
      : null;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OfferHeader(net: _net),
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
                          _RouteRow(
                            dot: null,
                            label: 'Посадка',
                            address: ride['pickup_address'] as String? ?? '—',
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 5),
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
                          _RouteRow(
                            dot: AppTheme.ink,
                            label: 'Назначение',
                            address:
                                ride['dropoff_address'] as String? ?? '—',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.straighten_rounded,
                            label: 'Расстояние',
                            value: ride['distance_km'] != null
                                ? '${double.parse(ride['distance_km'].toString()).toStringAsFixed(1)} км'
                                : '—',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.schedule_rounded,
                            label: 'В пути',
                            value: ride['duration_min'] != null
                                ? '~${double.parse(ride['duration_min'].toString()).toStringAsFixed(0)} мин'
                                : '—',
                          ),
                        ),
                      ],
                    ),
                    if (_price != null) ...[
                      const SizedBox(height: 12),
                      QadamCard(
                        radius: 20,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        color: AppTheme.mint,
                        borderColor: Colors.transparent,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              color: AppTheme.success,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Комиссия Qadam 0% — вся сумма ваша',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.success,
                                ),
                              ),
                            ),
                            Text(
                              '${_price!.toStringAsFixed(0)} сом',
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    QadamCard(
                      radius: 20,
                      padding: const EdgeInsets.all(16),
                      child: const Row(
                        children: [
                          QadamIconBadge(
                            icon: Icons.payments_rounded,
                            color: AppTheme.warning,
                            size: 40,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Оплата наличными или переводом — без онлайн-платежа',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
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
            8,
            16,
            MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Row(
            children: [
              Expanded(
                child: QadamActionButton(
                  label: 'Отклонить',
                  onTap: declining ? null : onDecline,
                  style: QadamButtonStyle.ghost,
                  loading: declining,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: QadamActionButton(
                  label: 'Принять заказ',
                  onTap: accepting ? null : onAccept,
                  loading: accepting,
                  icon: Icons.check_rounded,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfferHeader extends StatelessWidget {
  const _OfferHeader({required this.net});
  final double? net;

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
                          label: 'НОВЫЙ ЗАКАЗ',
                          color: Colors.white,
                          background: Color(0x33FFFFFF),
                          icon: Icons.bolt_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Ваш заработок',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      net != null ? '~${net!.toStringAsFixed(0)} сом' : '—',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white,
                        fontSize: 44,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Без комиссии · оплата наличными',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
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

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.dot,
    required this.label,
    required this.address,
  });

  final Color? dot;
  final String label;
  final String address;

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
            gradient: dot == null ? AppTheme.brandGradient : null,
            color: dot,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
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
                address,
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
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return QadamCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QadamIconBadge(icon: icon, size: 38),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
