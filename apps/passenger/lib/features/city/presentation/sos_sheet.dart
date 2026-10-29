import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

Future<void> showSosSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SosSheet(),
  );
}

class _SosSheet extends StatelessWidget {
  const _SosSheet();

  Future<void> _call(BuildContext context, String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const QadamIconBadge(
                icon: Icons.emergency_rounded,
                color: AppTheme.error,
                size: 64,
              ),
              const SizedBox(height: 14),
              const Text(
                'Экстренная помощь',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'В экстренной ситуации нажмите нужную кнопку для звонка',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              _SosBtn(
                label: 'Полиция',
                number: '102',
                color: AppTheme.primary,
                onTap: () => _call(context, '102'),
              ),
              const SizedBox(height: 10),
              _SosBtn(
                label: 'Скорая помощь',
                number: '103',
                color: AppTheme.error,
                onTap: () => _call(context, '103'),
              ),
              const SizedBox(height: 10),
              _SosBtn(
                label: 'Пожарная служба',
                number: '101',
                color: Color(0xFFFF5F3B),
                onTap: () => _call(context, '101'),
              ),
              const SizedBox(height: 12),
              QadamActionButton(
                label: 'Отмена',
                onTap: () => Navigator.of(context).pop(),
                style: QadamButtonStyle.ghost,
                height: 48,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosBtn extends StatelessWidget {
  const _SosBtn(
      {required this.label, required this.number, required this.color, required this.onTap});
  final String label;
  final String number;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return QadamCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 18,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.call_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  number,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        ],
      ),
    );
  }
}
