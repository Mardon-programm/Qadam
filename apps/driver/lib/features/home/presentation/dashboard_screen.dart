import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';

final _profileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(driverApiProvider).getProfile();
});

final _offersProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(driverApiProvider).getOffers();
});

final _onlineProvider = StateProvider<bool>((ref) => false);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _toggleOnline(bool newVal) async {
    try {
      final api = ref.read(driverApiProvider);
      final result = await api.setOnline(newVal);
      ref.read(_onlineProvider.notifier).state =
          result['online_status'] == 'online';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(_profileProvider);
    final offersAsync = ref.watch(_offersProvider);
    final isOnline = ref.watch(_onlineProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              floating: true,
              backgroundColor: AppTheme.surface,
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_taxi,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Qadam Driver'),
                ],
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Online toggle card
                  _OnlineCard(
                    isOnline: isOnline,
                    onToggle: _toggleOnline,
                  ),
                  const SizedBox(height: 16),

                  // Today's earnings
                  _EarningsCard(),
                  const SizedBox(height: 16),

                  // Pending offers
                  Text('Входящие заказы',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  offersAsync.when(
                    loading: () => const Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    )),
                    error: (e, _) =>
                        Text('Ошибка загрузки: $e',
                            style: const TextStyle(color: AppTheme.error)),
                    data: (offers) {
                      if (offers.isEmpty) {
                        return _EmptyOffers(isOnline: isOnline);
                      }
                      return Column(
                        children: offers
                            .map((o) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _OfferCard(
                                    offer: o as Map<String, dynamic>,
                                    onTap: () => context.push(
                                        '/dashboard/offer/${o['ride_order_id']}'),
                                  ),
                                ))
                            .toList(),
                      );
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlineCard extends StatelessWidget {
  const _OnlineCard({required this.isOnline, required this.onToggle});
  final bool isOnline;
  final Future<void> Function(bool) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOnline
              ? [AppTheme.secondary, const Color(0xFF00A844)]
              : [AppTheme.textSecondary, const Color(0xFF4B5563)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isOnline ? AppTheme.secondary : AppTheme.textSecondary)
                .withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'Вы онлайн' : 'Вы офлайн',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  isOnline
                      ? 'Получаете заказы'
                      : 'Нажмите, чтобы начать принимать заказы',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 1.2,
            child: Switch(
              value: isOnline,
              onChanged: onToggle,
              activeColor: Colors.white,
              activeTrackColor: Colors.white.withOpacity(0.4),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = FutureProvider<Map<String, dynamic>>((ref) async {
      return ref.read(driverApiProvider).getWalletBalance();
    });

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
              color: AppTheme.earningsGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet,
                color: AppTheme.earningsGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Баланс кошелька',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
              Text(
                '— сом',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.earningsGreen,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: () => GoRouter.of(context).go('/wallet'),
            child: const Text('Детали'),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.onTap});
  final Map<String, dynamic> offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final net = offer['net_estimate'];
    final eta = offer['eta_min'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Новый заказ',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  if (eta != null)
                    Text('До пассажира: ~$eta мин',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            if (net != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.earningsGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '~$net сом',
                  style: const TextStyle(
                      color: AppTheme.earningsGreen,
                      fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOffers extends StatelessWidget {
  const _EmptyOffers({required this.isOnline});
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            isOnline
                ? Icons.hourglass_empty
                : Icons.power_settings_new,
            size: 48,
            color: AppTheme.textSecondary.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text(
            isOnline
                ? 'Ожидаем заказы…'
                : 'Включите статус «онлайн», чтобы получать заказы',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
