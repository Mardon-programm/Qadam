import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_service.dart';
import '../../../core/api/models.dart';
import '../../../core/theme/app_theme.dart';

final _historyProvider = FutureProvider<_HistoryData>((ref) async {
  final api = ref.read(apiServiceProvider);
  final bookings = await api.getMyBookings();
  return _HistoryData(bookings: bookings);
});

class _HistoryData {
  final List<Booking> bookings;
  const _HistoryData({required this.bookings});
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histAsync = ref.watch(_historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('История')),
      body: histAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (data) {
          if (data.bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 64,
                      color: AppTheme.textSecondary.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  const Text('Поездок пока нет',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _BookingHistoryCard(booking: data.bookings[i]),
          );
        },
      ),
    );
  }
}

class _BookingHistoryCard extends StatelessWidget {
  const _BookingHistoryCard({required this.booking});
  final Booking booking;

  Color _statusColor() {
    return switch (booking.status) {
      'confirmed' => AppTheme.secondary,
      'completed' => AppTheme.primary,
      'cancelled' => AppTheme.error,
      _ => AppTheme.textSecondary,
    };
  }

  String _statusLabel() {
    return switch (booking.status) {
      'held' => 'Ожидает оплаты',
      'confirmed' => 'Подтверждена',
      'completed' => 'Завершена',
      'cancelled' => 'Отменена',
      _ => booking.status,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _statusColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(Icons.directions_bus, color: _statusColor(), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.tripId.substring(0, 8).toUpperCase(),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(),
                        style: TextStyle(
                            color: _statusColor(),
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${booking.totalPrice.toStringAsFixed(0)} сом',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
