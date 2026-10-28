import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';
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
      pickupAddress:
          '${widget.pickup.latitude.toStringAsFixed(4)}, ${widget.pickup.longitude.toStringAsFixed(4)}',
      pickupLat: widget.pickup.latitude,
      pickupLng: widget.pickup.longitude,
      dropoffAddress:
          '${widget.dropoff.latitude.toStringAsFixed(4)}, ${widget.dropoff.longitude.toStringAsFixed(4)}',
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
        pickupAddress:
            '${widget.pickup.latitude.toStringAsFixed(4)}, ${widget.pickup.longitude.toStringAsFixed(4)}',
        pickupLat: widget.pickup.latitude,
        pickupLng: widget.pickup.longitude,
        dropoffAddress:
            '${widget.dropoff.latitude.toStringAsFixed(4)}, ${widget.dropoff.longitude.toStringAsFixed(4)}',
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

    return QadamSheet(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const QadamIconBadge(
                icon: Icons.local_taxi_rounded,
                size: 46,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Qadam City',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Ближайший водитель · ~5 мин',
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
              const QadamTag(
                label: 'сом',
                color: AppTheme.secondary,
                icon: Icons.payments_rounded,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!_quoteFetched || quote == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'СТОИМОСТЬ ПОЕЗДКИ',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${quote.quotedPrice.toStringAsFixed(0)} сом',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                          height: 1.05,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const QadamTag(
                  label: 'Далее',
                  icon: Icons.route_rounded,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Chip(
                  icon: Icons.route_rounded,
                  label: '${quote.distanceKm.toStringAsFixed(1)} км',
                ),
                const SizedBox(width: 8),
                _Chip(
                  icon: Icons.schedule_rounded,
                  label: '~${quote.durationMin.toStringAsFixed(0)} мин',
                ),
              ],
            ),
            if (quote.surgeMultiplier > 1.0) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: QadamTag(
                  label:
                      'Повышенный спрос ×${quote.surgeMultiplier.toStringAsFixed(1)}',
                  color: AppTheme.warning,
                  icon: Icons.bolt_rounded,
                ),
              ),
            ],
            const SizedBox(height: 22),
            QadamActionButton(
              label: 'Заказать',
              loading: _booking,
              onTap: _confirm,
              icon: Icons.arrow_forward_rounded,
            ),
            const SizedBox(height: 6),
            QadamActionButton(
              label: 'Отмена',
              style: QadamButtonStyle.link,
              height: 44,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
