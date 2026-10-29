import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

class CancelReason {
  final String code;
  final String title;
  const CancelReason({required this.code, required this.title});
}

const kPassengerCancelReasons = [
  CancelReason(code: 'changed_mind', title: 'Изменились планы'),
  CancelReason(code: 'wait_too_long', title: 'Думал(а) дольше'),
  CancelReason(code: 'wrong_address', title: 'Неправильный адрес'),
  CancelReason(code: 'found_another', title: 'Нашёл(ла) другой вариант'),
  CancelReason(code: 'cant_find_driver', title: 'Не могу найти водителя'),
  CancelReason(code: 'other', title: 'Другое'),
];

Future<String?> showCancelReasonSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _CancelReasonSheet(),
  );
}

class _CancelReasonSheet extends StatelessWidget {
  const _CancelReasonSheet();

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
              const Text(
                'Почему отменяете?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Выберите причину — это поможет улучшить сервис',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ...kPassengerCancelReasons.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: QadamCard(
                    onTap: () => Navigator.of(context).pop(r.code),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    radius: 18,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.title,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              QadamActionButton(
                label: 'Назад',
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
