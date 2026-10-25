import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';

final _walletProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(driverApiProvider).getWalletHistory();
});

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(_walletProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Кошелёк')),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (wallet) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Balance card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Доступно для вывода',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      '${_fmt(wallet['available_for_payout'])} сом',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _MiniStat(
                            label: 'Заработано',
                            value: _fmt(wallet['gross_earned']),
                            color: Colors.white),
                        const SizedBox(width: 24),
                        _MiniStat(
                            label: 'Выведено',
                            value: _fmt(wallet['paid_out']),
                            color: Colors.white70),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Period info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  children: [
                    _StatRow(
                      label: 'Период',
                      value: '${wallet['period_days']} дней',
                    ),
                    const Divider(height: 20),
                    _StatRow(
                      label: 'Валовой доход',
                      value: '${_fmt(wallet['gross_earned'])} сом',
                      valueColor: AppTheme.earningsGreen,
                    ),
                    const Divider(height: 20),
                    _StatRow(
                      label: 'Списания',
                      value: '${_fmt(wallet['debited'])} сом',
                      valueColor: AppTheme.error,
                    ),
                    const Divider(height: 20),
                    _StatRow(
                      label: 'Чистый баланс',
                      value: '${_fmt(wallet['net_balance'])} сом',
                      valueColor: AppTheme.primary,
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Withdrawal CTA
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Вывод средств — скоро')),
                  );
                },
                child: const Text('Вывести средства'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    final d = double.tryParse(v.toString()) ?? 0.0;
    return d.toStringAsFixed(0);
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 12)),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: AppTheme.textSecondary)),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppTheme.textPrimary,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Add AppTheme.primaryDark (missing in driver theme) as constant
extension _PrimaryDark on AppTheme {
  static const Color primaryDark = Color(0xFF1558C0);
}
