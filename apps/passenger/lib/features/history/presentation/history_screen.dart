import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_service.dart';
import '../../../core/api/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

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
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_historyProvider),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _HistoryHeader()),
            SliverToBoxAdapter(
              child: histAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (data) => Transform.translate(
                  offset: const Offset(0, -30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SummaryCard(data: data),
                  ),
                ),
              ),
            ),
            histAsync.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
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
              ),
              data: (data) {
                if (data.bookings.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyHistory(),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: data.bookings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _BookingHistoryCard(
                      booking: data.bookings[i],
                    ),
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
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 44),
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
                      'Все ваши междугородние поездки в одном месте',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white.withValues(alpha: 0.8),
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
    final total = data.bookings.fold<double>(
      0,
      (sum, b) => sum + b.totalPrice,
    );
    return QadamCard(
      radius: 26,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: QadamStat(
              value: '${data.bookings.length}',
              label: 'поездок',
              icon: Icons.receipt_long_rounded,
            ),
          ),
          Container(width: 1, height: 42, color: AppTheme.divider),
          const SizedBox(width: 16),
          Expanded(
            child: QadamStat(
              value: '${total.toStringAsFixed(0)} сом',
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

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
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
            'Как только вы забронируете междугороднюю поездку, она появится здесь',
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
    final color = _statusColor();
    return QadamCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          QadamIconBadge(
            icon: Icons.directions_bus_filled_rounded,
            color: color,
            size: 48,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.tripId.substring(0, 8).toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                QadamTag(
                  label: _statusLabel(),
                  color: color,
                ),
              ],
            ),
          ),
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
