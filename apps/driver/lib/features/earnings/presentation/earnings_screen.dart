import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  Map<String, dynamic>? _stats;
  List<dynamic> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = ref.read(driverApiProvider);
      final stats = await api.getEarningsStats();
      final trips = await api.getCompletedTrips();

      if (mounted) {
        setState(() {
          _stats = stats;
          _trips = trips;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.surface,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final todayEarnings = _stats?['today_earnings'] ?? 0.0;
    final weekEarnings = _stats?['week_earnings'] ?? 0.0;
    final monthEarnings = _stats?['month_earnings'] ?? 0.0;
    final tripsToday = _stats?['trips_today'] ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _EarningsHeader(
                today: _num(todayEarnings),
                tripsToday: tripsToday is int ? tripsToday : 0,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -30),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _PeriodCard(
                              icon: Icons.view_week_rounded,
                              title: 'Неделя',
                              amount: _num(weekEarnings),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PeriodCard(
                              icon: Icons.calendar_month_rounded,
                              title: 'Месяц',
                              amount: _num(monthEarnings),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const QadamSectionLabel('История поездок'),
                    ],
                  ),
                ),
              ),
            ),
            if (_trips.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'Нет завершённых поездок',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: _trips.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final trip = _trips[index];
                    return _TripRow(trip: trip as Map<String, dynamic>);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class _EarningsHeader extends StatelessWidget {
  const _EarningsHeader({required this.today, required this.tripsToday});
  final double today;
  final int tripsToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.sunGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
        child: Stack(
          children: [
            Positioned.fill(
              child: QadamOrnament(opacity: 0.22, color: AppTheme.ink),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 54),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const QadamWordmark(size: 20),
                        const Spacer(),
                        QadamTag(
                          label: '$tripsToday поездок',
                          color: AppTheme.ink,
                          background: AppTheme.ink.withValues(alpha: 0.1),
                          icon: Icons.local_taxi_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Заработано сегодня',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: AppTheme.ink.withValues(alpha: 0.65),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${today.toStringAsFixed(0)} сом',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        color: AppTheme.ink,
                        fontSize: 44,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Комиссия 0% — вся сумма остаётся вам',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: AppTheme.ink.withValues(alpha: 0.62),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.icon,
    required this.title,
    required this.amount,
  });

  final IconData icon;
  final String title;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return QadamCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QadamIconBadge(icon: icon, size: 40),
          const SizedBox(height: 14),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${amount.toStringAsFixed(0)} сом',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.trip});
  final Map<String, dynamic> trip;

  @override
  Widget build(BuildContext context) {
    final net = trip['driver_net'];
    final distance = trip['distance_km'];
    final completedAt = trip['completed_at'];

    return QadamCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const QadamIconBadge(
            icon: Icons.check_rounded,
            color: AppTheme.success,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trip['pickup_address']} → ${trip['dropoff_address']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  completedAt != null
                      ? '$completedAt'
                      : '${distance ?? '—'} км',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${net ?? '—'} сом',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.success,
                ),
              ),
              if (completedAt != null)
                Text(
                  '${distance ?? '—'} км',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
