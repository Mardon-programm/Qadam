import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';

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
      if (mounted) setState(() { _ride = ride; _loading = false; });
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
        context.go('/dashboard');
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
      appBar: AppBar(
        title: const Text('Новый заказ'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ride == null
              ? const Center(child: Text('Заказ не найден'))
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        children: [
          // Earnings highlight
          if (_net != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [
                  AppTheme.earningsGreen,
                  Color(0xFF00A844),
                ]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text('Ваш заработок',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Text(
                    '~${_net!.toStringAsFixed(0)} сом',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Route
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              children: [
                _RouteRow(
                  icon: Icons.my_location,
                  color: AppTheme.primary,
                  label: 'Посадка',
                  address: ride['pickup_address'] as String? ?? '—',
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 22),
                  child: Divider(height: 20),
                ),
                _RouteRow(
                  icon: Icons.location_on,
                  color: AppTheme.error,
                  label: 'Назначение',
                  address: ride['dropoff_address'] as String? ?? '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Details row
          Row(
            children: [
              Expanded(
                child: _DetailCard(
                  icon: Icons.straighten,
                  label: 'Расстояние',
                  value: ride['distance_km'] != null
                      ? '${double.parse(ride['distance_km'].toString()).toStringAsFixed(1)} км'
                      : '—',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DetailCard(
                  icon: Icons.timer,
                  label: 'Время',
                  value: ride['duration_min'] != null
                      ? '~${double.parse(ride['duration_min'].toString()).toStringAsFixed(0)} мин'
                      : '—',
                ),
              ),
            ],
          ),

          const Spacer(),

          // CTA buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: declining ? null : onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                  ),
                  child: declining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.error))
                      : const Text('Отклонить'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: accepting ? null : onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.earningsGreen,
                  ),
                  child: accepting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, size: 18),
                            SizedBox(width: 6),
                            Text('Принять'),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.address,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              Text(address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
              Text(value,
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ],
      ),
    );
  }
}
