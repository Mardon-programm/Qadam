import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_service.dart';
import '../../../core/api/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

final _historyProvider = FutureProvider<_HistoryData>((ref) async {
  final api = ref.read(apiServiceProvider);
  var failed = true;

  var rides = <RideOrder>[];
  try {
    rides = await api.getMyRides();
    failed = false;
  } catch (_) {
    // Keep the other source visible if only one request fails.
  }

  var bookings = <Booking>[];
  try {
    bookings = await api.getMyBookings();
    failed = false;
  } catch (_) {
    // Keep the other source visible if only one request fails.
  }

  return _HistoryData(
    rides: rides,
    bookings: bookings,
    failed: failed && rides.isEmpty && bookings.isEmpty,
  );
});

enum _TripKind { city, intercity }

class _HistoryData {
  const _HistoryData({
    required this.rides,
    required this.bookings,
    this.failed = false,
  });

  final List<RideOrder> rides;
  final List<Booking> bookings;
  final bool failed;

  List<_HistoryEntry> get entries {
    final items = <_HistoryEntry>[
      ...rides.map(_HistoryEntry.city),
      ...bookings.map(_HistoryEntry.intercity),
    ];
    items.sort((a, b) {
      final left = a.date;
      final right = b.date;
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return items;
  }

  double get totalSpent => entries.fold(0, (sum, e) => sum + e.price);
}

class _HistoryEntry {
  const _HistoryEntry.city(RideOrder this.ride) : booking = null;
  const _HistoryEntry.intercity(Booking this.booking) : ride = null;

  final RideOrder? ride;
  final Booking? booking;

  _TripKind get kind => ride != null ? _TripKind.city : _TripKind.intercity;

  DateTime? get date => ride?.createdAt ?? booking?.createdAt ?? booking?.departAt;

  double get price => ride != null
      ? (ride!.finalPrice ?? ride!.quotedPrice ?? 0)
      : booking!.totalPrice;
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _TripKind? _filter;

  @override
  Widget build(BuildContext context) {
    final histAsync = ref.watch(_historyProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_historyProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: _HistoryHeader()),
            SliverToBoxAdapter(
              child: histAsync.maybeWhen(
                data: (data) => Transform.translate(
                  offset: const Offset(0, -32),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SummaryCard(data: data),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ),
            histAsync.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(
                  message: '$e',
                  onRetry: () => ref.invalidate(_historyProvider),
                ),
              ),
              data: (data) {
                if (data.failed) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ErrorState(
                      message: 'Не удалось загрузить историю поездок',
                      onRetry: () => ref.invalidate(_historyProvider),
                    ),
                  );
                }

                final all = data.entries;
                final entries = _filter == null
                    ? all
                    : all.where((e) => e.kind == _filter).toList();

                if (all.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyHistory(),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _FilterRow(
                        filter: _filter,
                        onChanged: (value) => setState(() => _filter = value),
                        cityCount: data.rides.length,
                        intercityCount: data.bookings.length,
                      ),
                      const SizedBox(height: 16),
                      if (entries.isEmpty)
                        const _FilterEmpty()
                      else
                        for (final entry in entries) ...[
                          _HistoryCard(entry: entry),
                          const SizedBox(height: 12),
                        ],
                    ]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader();

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
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const QadamWordmark(onDark: true),
                    const SizedBox(height: 28),
                    const Text(
                      'История поездок',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Городские и междугородние поездки в одном месте',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 14,
                        height: 1.4,
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});
  final _HistoryData data;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries;
    return QadamCard(
      radius: 26,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: QadamStat(
              value: '${entries.length}',
              label: 'поездок',
              icon: Icons.route_rounded,
            ),
          ),
          Container(width: 1, height: 42, color: AppTheme.divider),
          const SizedBox(width: 16),
          Expanded(
            child: QadamStat(
              value: '${data.totalSpent.toStringAsFixed(0)} сом',
              label: 'потрачено',
              icon: Icons.payments_rounded,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filter,
    required this.onChanged,
    required this.cityCount,
    required this.intercityCount,
  });

  final _TripKind? filter;
  final ValueChanged<_TripKind?> onChanged;
  final int cityCount;
  final int intercityCount;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterPill(
            label: 'Все',
            count: cityCount + intercityCount,
            selected: filter == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 8),
          _FilterPill(
            label: 'Такси',
            count: cityCount,
            icon: Icons.local_taxi_rounded,
            selected: filter == _TripKind.city,
            onTap: () => onChanged(_TripKind.city),
          ),
          const SizedBox(width: 8),
          _FilterPill(
            label: 'Межгород',
            count: intercityCount,
            icon: Icons.directions_bus_filled_rounded,
            selected: filter == _TripKind.intercity,
            onTap: () => onChanged(_TripKind.intercity),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppTheme.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.brandGradient : null,
          color: selected ? null : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.transparent : AppTheme.divider,
          ),
          boxShadow: selected ? AppTheme.softShadow : null,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.24)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});
  final _HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return entry.ride != null
        ? _CityRideCard(ride: entry.ride!)
        : _BookingCard(booking: entry.booking!);
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return QadamTag(label: label, color: color);
  }
}

class _CityRideCard extends StatelessWidget {
  const _CityRideCard({required this.ride});
  final RideOrder ride;

  (String, Color) get _status {
    return switch (ride.status) {
      'completed' => ('Завершена', AppTheme.success),
      'cancelled' => ('Отменена', AppTheme.error),
      'failed' => ('Не состоялась', AppTheme.error),
      'in_progress' => ('В поездке', AppTheme.primary),
      'assigned' || 'driver_arriving' || 'driver_arrived' => (
          'Водитель в пути',
          AppTheme.primary,
        ),
      'searching' || 'offered' => ('Ищем водителя', AppTheme.warning),
      _ => ('Ожидает', AppTheme.textSecondary),
    };
  }

  String get _date {
    final at = ride.createdAt;
    if (at == null) return 'Городская поездка';
    return DateFormat('d MMM, HH:mm', 'ru').format(at.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _status;
    final price = ride.finalPrice ?? ride.quotedPrice;
    final details = <String>[
      if (ride.distanceKm != null) '${ride.distanceKm!.toStringAsFixed(1)} км',
      if (ride.durationMin != null) '~${ride.durationMin!.toStringAsFixed(0)} мин',
    ];

    return QadamCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              QadamIconBadge(
                icon: Icons.local_taxi_rounded,
                color: AppTheme.primary,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Такси по городу',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _date,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price == null ? '—' : '${price.toStringAsFixed(0)} сом',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StatusTag(label: statusLabel, color: statusColor),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _RouteRow(
                  color: AppTheme.success,
                  label: 'Откуда',
                  address: ride.pickupAddress,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 1,
                        height: 12,
                        color: AppTheme.divider,
                      ),
                    ],
                  ),
                ),
                _RouteRow(
                  color: AppTheme.primary,
                  label: 'Куда',
                  address: ride.dropoffAddress,
                ),
              ],
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.straighten_rounded,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  details.join(' · '),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.color,
    required this.label,
    required this.address,
  });

  final Color color;
  final String label;
  final String address;

  /// Backend stores raw coordinates until reverse geocoding is wired in.
  String get _prettyAddress {
    final looksLikeCoords =
        RegExp(r'^-?\d{1,2}\.\d{3,},\s*-?\d{1,3}\.\d{3,}$').hasMatch(address);
    return looksLikeCoords ? 'Точка на карте · $address' : address;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                _prettyAddress,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  height: 1.25,
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

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});
  final Booking booking;

  (String, Color) get _status {
    return switch (booking.status) {
      'confirmed' => ('Подтверждена', AppTheme.success),
      'completed' => ('Завершена', AppTheme.primary),
      'cancelled' => ('Отменена', AppTheme.error),
      'held' => ('Ожидает оплаты', AppTheme.warning),
      _ => (booking.status, AppTheme.textSecondary),
    };
  }

  String get _title {
    final from = booking.originCity;
    final to = booking.destinationCity;
    if (from != null && to != null) return '$from → $to';
    return 'Межгород · ${booking.tripId.substring(0, 8).toUpperCase()}';
  }

  String get _subtitle {
    final at = booking.departAt ?? booking.createdAt;
    final date =
        at == null ? null : DateFormat('d MMM, HH:mm', 'ru').format(at.toLocal());
    final seats = booking.passengerCount == 1
        ? '1 место'
        : '${booking.passengerCount} места';
    return [if (date != null) date, seats].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _status;
    return QadamCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          QadamIconBadge(
            icon: Icons.directions_bus_filled_rounded,
            color: AppTheme.secondary,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                _StatusTag(label: statusLabel, color: statusColor),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${booking.totalPrice.toStringAsFixed(0)} сом',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterEmpty extends StatelessWidget {
  const _FilterEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const QadamIconBadge(
            icon: Icons.search_off_rounded,
            color: AppTheme.textSecondary,
            size: 56,
          ),
          const SizedBox(height: 14),
          Text(
            'В этой категории пока пусто',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              gradient: AppTheme.brandGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Поездок пока нет',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Закажите такси по городу или забронируйте межгород — все поездки появятся здесь',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              const Text(
                'Не удалось загрузить',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              QadamActionButton(
                label: 'Повторить',
                onTap: onRetry,
                icon: Icons.refresh_rounded,
                height: 48,
                expand: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
