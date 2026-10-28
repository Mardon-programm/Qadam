import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

final _walletProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(driverApiProvider).getWalletHistory();
});

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(_walletProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: walletAsync.when(
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
                  const SizedBox(height: 16),
                  QadamActionButton(
                    label: 'Повторить',
                    onTap: () => ref.invalidate(_walletProvider),
                    style: QadamButtonStyle.soft,
                    height: 48,
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (wallet) => ListView(
          padding: EdgeInsets.zero,
          children: [
            _WalletHeader(wallet: wallet, fmt: _fmt),
            Transform.translate(
              offset: const Offset(0, -32),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    QadamCard(
                      radius: 26,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
                      child: Column(
                        children: [
                          QadamInfoRow(
                            icon: Icons.calendar_month_rounded,
                            label: 'Период',
                            value: '${wallet['period_days']} дней',
                          ),
                          const Divider(height: 1),
                          QadamInfoRow(
                            icon: Icons.trending_up_rounded,
                            label: 'Валовой доход',
                            value: '${_fmt(wallet['gross_earned'])} сом',
                            valueColor: AppTheme.success,
                          ),
                          const Divider(height: 1),
                          QadamInfoRow(
                            icon: Icons.trending_down_rounded,
                            label: 'Списания',
                            value: '${_fmt(wallet['debited'])} сом',
                            valueColor: AppTheme.error,
                          ),
                          const Divider(height: 1),
                          QadamInfoRow(
                            icon: Icons.account_balance_rounded,
                            label: 'Чистый баланс',
                            value: '${_fmt(wallet['net_balance'])} сом',
                            valueColor: AppTheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    QadamCard(
                      radius: 22,
                      color: AppTheme.mint,
                      borderColor: Colors.transparent,
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: AppTheme.success,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Комиссия Qadam для водителей — 0%. Вы получаете полную стоимость поездки.',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    QadamActionButton(
                      label: 'Вывести средства',
                      icon: Icons.account_balance_wallet_rounded,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Вывод средств — скоро'),
                          ),
                        );
                      },
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

  static String _fmt(dynamic v) {
    if (v == null) return '0';
    final d = double.tryParse(v.toString()) ?? 0.0;
    return d.toStringAsFixed(0);
  }
}

class _WalletHeader extends StatelessWidget {
  const _WalletHeader({required this.wallet, required this.fmt});
  final Map<String, dynamic> wallet;
  final String Function(dynamic) fmt;

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
              child: QadamOrnament(
                opacity: 0.22,
                color: AppTheme.ink,
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const QadamWordmark(size: 20),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.ink.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_rounded,
                                size: 14,
                                color: AppTheme.ink,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Кошелёк',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Доступно для вывода',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: AppTheme.ink.withValues(alpha: 0.65),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${fmt(wallet['available_for_payout'])} сом',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        color: AppTheme.ink,
                        fontSize: 42,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _MiniStat(
                          label: 'Заработано',
                          value: fmt(wallet['gross_earned']),
                        ),
                        const SizedBox(width: 28),
                        _MiniStat(
                          label: 'Выведено',
                          value: fmt(wallet['paid_out']),
                        ),
                      ],
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: AppTheme.ink.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '$value сом',
          style: const TextStyle(
            fontFamily: 'Manrope',
            color: AppTheme.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
