import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';

final _myTripsProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(driverApiProvider).getMyTrips();
});

class MyTripsScreen extends ConsumerWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(_myTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои рейсы'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/trips/new'),
          ),
        ],
      ),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (trips) {
          if (trips.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_bus_outlined,
                      size: 64,
                      color: AppTheme.textSecondary.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  const Text('Рейсов нет',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => context.push('/trips/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Создать рейс'),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) =>
                _TripCard(trip: trips[i] as Map<String, dynamic>),
          );
        },
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});
  final Map<String, dynamic> trip;

  Color _statusColor() => switch (trip['status'] as String) {
        'scheduled' => AppTheme.primary,
        'departed' => AppTheme.warning,
        'completed' => AppTheme.secondary,
        _ => AppTheme.error,
      };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM, HH:mm', 'ru');
    final depart = trip['depart_at'] as String?;
    final departDate = depart != null ? DateTime.tryParse(depart) : null;
    final color = _statusColor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${trip['origin_city']} → ${trip['destination_city']}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trip['status'] as String,
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule,
                  size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                departDate != null ? fmt.format(departDate) : '—',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.event_seat,
                  size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                '${trip['available_seats']}/${trip['seat_count']} мест',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '${trip['price_per_seat']} сом',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppTheme.earningsGreen),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension _Earnings on AppTheme {
  static const Color earningsGreen = Color(0xFF00C853);
}
