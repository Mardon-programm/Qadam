import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PriceBadge extends StatelessWidget {
  const PriceBadge({
    super.key,
    required this.amount,
    required this.currency,
    this.isSurge = false,
    this.surgeMultiplier = 1.0,
  });

  final double amount;
  final String currency;
  final bool isSurge;
  final double surgeMultiplier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSurge
            ? AppTheme.warning.withOpacity(0.12)
            : AppTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSurge) ...[
            Icon(Icons.flash_on, size: 14, color: AppTheme.warning),
            const SizedBox(width: 2),
          ],
          Text(
            '${amount.toStringAsFixed(0)} $currency',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isSurge ? AppTheme.warning : AppTheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
