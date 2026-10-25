import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_button.dart';
import '../data/city_provider.dart';

class RideQuoteSheet extends ConsumerStatefulWidget {
  const RideQuoteSheet({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.onConfirm,
  });

  final LatLng pickup;
  final LatLng dropoff;
  final void Function(String rideId) onConfirm;

  @override
  ConsumerState<RideQuoteSheet> createState() => _RideQuoteSheetState();
}

class _RideQuoteSheetState extends ConsumerState<RideQuoteSheet> {
  bool _quoteFetched = false;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _fetchQuote();
  }

  Future<void> _fetchQuote() async {
    final notifier = ref.read(cityRideNotifierProvider.notifier);
    await notifier.quote(
      pickupAddress: '${widget.pickup.latitude.toStringAsFixed(4)}, ${widget.pickup.longitude.toStringAsFixed(4)}',
      pickupLat: widget.pickup.latitude,
      pickupLng: widget.pickup.longitude,
      dropoffAddress: '${widget.dropoff.latitude.toStringAsFixed(4)}, ${widget.dropoff.longitude.toStringAsFixed(4)}',
      dropoffLat: widget.dropoff.latitude,
      dropoffLng: widget.dropoff.longitude,
    );
    if (mounted) setState(() => _quoteFetched = true);
  }

  Future<void> _confirm() async {
    setState(() => _booking = true);
    try {
      final notifier = ref.read(cityRideNotifierProvider.notifier);
      final ride = await notifier.createRide(
        pickupAddress: '${widget.pickup.latitude.toStringAsFixed(4)}, ${widget.pickup.longitude.toStringAsFixed(4)}',
        pickupLat: widget.pickup.latitude,
        pickupLng: widget.pickup.longitude,
        dropoffAddress: '${widget.dropoff.latitude.toStringAsFixed(4)}, ${widget.dropoff.longitude.toStringAsFixed(4)}',
        dropoffLat: widget.dropoff.latitude,
        dropoffLng: widget.dropoff.longitude,
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onConfirm(ride.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = ref.watch(quoteProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          if (!_quoteFetched)
            const Center(child: CircularProgressIndicator())
          else if (quote == null)
            const Text('Не удалось получить цену')
          else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Стоимость поездки',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        '${quote.quotedPrice.toStringAsFixed(0)} сом',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _InfoChip(
                        icon: Icons.route,
                        label: '${quote.distanceKm.toStringAsFixed(1)} км'),
                    const SizedBox(height: 4),
                    _InfoChip(
                        icon: Icons.timer,
                        label: '~${quote.durationMin.toStringAsFixed(0)} мин'),
                  ],
                ),
              ],
            ),
            if (quote.surgeMultiplier > 1.0) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flash_on,
                        color: AppTheme.warning, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Повышенный спрос ×${quote.surgeMultiplier.toStringAsFixed(1)}',
                      style: const TextStyle(
                          color: AppTheme.warning,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            QadamButton(
              label: 'Заказать',
              isLoading: _booking,
              onPressed: _confirm,
              icon: Icons.directions_car,
            ),
            const SizedBox(height: 12),
            QadamButton(
              label: 'Отмена',
              variant: QadamButtonVariant.text,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary)),
      ],
    );
  }
}
