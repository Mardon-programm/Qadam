import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';

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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final todayEarnings = _stats?['today_earnings'] ?? 0.0;
    final weekEarnings = _stats?['week_earnings'] ?? 0.0;
    final monthEarnings = _stats?['month_earnings'] ?? 0.0;
    final tripsToday = _stats?['trips_today'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заработок'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // Stats cards
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    _StatCard(
                      title: 'Сегодня',
                      amount: todayEarnings,
                      trips: tripsToday,
                      color: AppTheme.success,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Неделя',
                            amount: weekEarnings,
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Месяц',
                            amount: monthEarnings,
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'История поездок',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Trip list
            if (_trips.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text('Нет завершенных поездок'),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final trip = _trips[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primary.withOpacity(0.1),
                            child: const Icon(Icons.check,
                                color: AppTheme.primary),
                          ),
                          title: Text('${trip['pickup_address']} → ${trip['dropoff_address']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(trip['completed_at'] ?? ''),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${trip['driver_net']} с',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.success,
                                ),
                              ),
                              Text(
                                '${trip['distance_km']} км',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _trips.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.amount,
    this.trips,
    this.compact = false,
    this.color,
  });

  final String title;
  final double amount;
  final int? trips;
  final bool compact;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: color?.withOpacity(0.1) ?? AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color?.withOpacity(0.3) ?? AppTheme.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '${amount.toStringAsFixed(0)} с',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
          if (trips != null) ...[
            const SizedBox(height: 4),
            Text(
              '$trips ${trips == 1 ? 'поездка' : trips! < 5 ? 'поездки' : 'поездок'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
