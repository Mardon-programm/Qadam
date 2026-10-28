import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

final _tripDetailsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, tripId) async {
  final api = ref.read(apiServiceProvider);
  return api
      .get('/region/trips/$tripId')
      .then((r) => r.data as Map<String, dynamic>);
});

class TripDetailsScreen extends ConsumerWidget {
  const TripDetailsScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(_tripDetailsProvider(tripId));

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: tripAsync.when(
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
                    size: 54,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Ошибка: $e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (trip) => _TripDetailsBody(trip: trip, tripId: tripId),
      ),
    );
  }
}

class _TripDetailsBody extends StatelessWidget {
  const _TripDetailsBody({required this.trip, required this.tripId});
  final Map<String, dynamic> trip;
  final String tripId;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMMM yyyy, HH:mm', 'ru');
    final departAt = DateTime.parse(trip['depart_at']);
    final driverName = trip['driver']?['name'] ?? 'Водитель';
    final vehicleInfo = trip['vehicle']?['model'] ?? 'Автомобиль';
    final pricePerSeat = (trip['price_per_seat'] ?? 0).toDouble();
    final availableSeats = trip['available_seats'] ?? 0;
    final totalSeats = trip['total_seats'] ?? 0;

    return Column(
      children: [
        _RouteHeader(
          origin: trip['origin'] ?? '',
          destination: trip['destination'] ?? '',
          departLabel: fmt.format(departAt),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Transform.translate(
                offset: const Offset(0, -30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    QadamCard(
                      radius: 24,
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          QadamAvatar(name: driverName, size: 56),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  driverName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      color: AppTheme.sun,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${trip['driver']?['rating'] ?? 5.0}',
                                      style: const TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const QadamTag(
                            label: 'Проверен',
                            color: AppTheme.success,
                            background: AppTheme.mint,
                            icon: Icons.verified_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    QadamCard(
                      radius: 22,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const QadamIconBadge(
                            icon: Icons.directions_car_filled_rounded,
                            size: 50,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vehicleInfo,
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  trip['vehicle']?['license_plate'] ?? '',
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 13,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const QadamSectionLabel('Детали поездки'),
                    const SizedBox(height: 10),
                    QadamCard(
                      radius: 22,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          QadamInfoRow(
                            icon: Icons.event_seat_rounded,
                            label: 'Доступно мест',
                            value: '$availableSeats из $totalSeats',
                          ),
                          const Divider(height: 1),
                          QadamInfoRow(
                            icon: Icons.payments_rounded,
                            label: 'Цена за место',
                            value: '${pricePerSeat.toStringAsFixed(0)} сом',
                            valueColor: AppTheme.primary,
                          ),
                          if (trip['meeting_point'] != null) ...[
                            const Divider(height: 1),
                            QadamInfoRow(
                              icon: Icons.location_on_rounded,
                              label: 'Место встречи',
                              value: '${trip['meeting_point']}',
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trip['description'] != null) ...[
                      const SizedBox(height: 16),
                      QadamCard(
                        radius: 22,
                        color: AppTheme.lavender,
                        borderColor: Colors.transparent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.info_rounded,
                                  color: AppTheme.primary,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Дополнительная информация',
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    color: AppTheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${trip['description']}',
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    QadamActionButton(
                      label: 'Забронировать место',
                      icon: Icons.check_circle_rounded,
                      onTap: () =>
                          context.push('/region/trips/$tripId/book'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteHeader extends StatelessWidget {
  const _RouteHeader({
    required this.origin,
    required this.destination,
    required this.departLabel,
  });

  final String origin;
  final String destination;
  final String departLabel;

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
            const Positioned.fill(child: QadamOrnament(opacity: 0.15)),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 50),
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
                            onTap: () => context.pop(),
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
                          label: 'Рейс',
                          color: Colors.white,
                          background: Color(0x33FFFFFF),
                          icon: Icons.directions_bus_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: _Point(
                            label: 'Откуда',
                            value: origin,
                            alignEnd: false,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 22,
                          ),
                        ),
                        Expanded(
                          child: _Point(
                            label: 'Куда',
                            value: destination,
                            alignEnd: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            departLabel,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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

class _Point extends StatelessWidget {
  const _Point({
    required this.label,
    required this.value,
    required this.alignEnd,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: const TextStyle(
            fontFamily: 'Manrope',
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
