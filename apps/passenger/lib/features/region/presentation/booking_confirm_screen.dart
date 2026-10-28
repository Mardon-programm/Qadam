import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';
import '../data/region_provider.dart';

class BookingConfirmScreen extends ConsumerStatefulWidget {
  const BookingConfirmScreen({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<BookingConfirmScreen> createState() =>
      _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends ConsumerState<BookingConfirmScreen> {
  int _passengers = 1;
  int _baggage = 0;
  bool _booking = false;

  Future<void> _book() async {
    setState(() => _booking = true);
    try {
      final notifier = ref.read(myBookingsProvider.notifier);
      await notifier.createBooking(
        tripId: widget.tripId,
        passengerCount: _passengers,
        baggageCount: _baggage,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Место забронировано! Ожидайте подтверждения.'),
            backgroundColor: AppTheme.secondary,
          ),
        );
        context.go('/history');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          const QadamBrandHeader(
            showBack: true,
            title: 'Подтверждение',
            subtitle: 'Сколько мест бронируем?',
            bottomRadius: 36,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Transform.translate(
                  offset: const Offset(0, -26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      QadamCard(
                        radius: 28,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Column(
                          children: [
                            _CounterRow(
                              icon: Icons.person_rounded,
                              label: 'Пассажиры',
                              hint: 'до 8 человек',
                              value: _passengers,
                              onDecrement: _passengers > 1
                                  ? () => setState(() => _passengers--)
                                  : null,
                              onIncrement: _passengers < 8
                                  ? () => setState(() => _passengers++)
                                  : null,
                            ),
                            const Divider(height: 1),
                            _CounterRow(
                              icon: Icons.work_rounded,
                              label: 'Багаж',
                              hint: 'до 4 мест',
                              value: _baggage,
                              onDecrement: _baggage > 0
                                  ? () => setState(() => _baggage--)
                                  : null,
                              onIncrement: _baggage < 4
                                  ? () => setState(() => _baggage++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      QadamCard(
                        radius: 22,
                        color: AppTheme.lavender,
                        borderColor: Colors.transparent,
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.timer_rounded,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'После бронирования у вас есть 5 минут для оплаты. Неоплаченная бронь отменяется.',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  color: AppTheme.primary,
                                  fontSize: 13,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      QadamActionButton(
                        label: 'Забронировать',
                        loading: _booking,
                        onTap: _book,
                        icon: Icons.check_rounded,
                      ),
                      const SizedBox(height: 8),
                      QadamActionButton(
                        label: 'Назад',
                        style: QadamButtonStyle.link,
                        height: 48,
                        onTap: () => context.pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final IconData icon;
  final String label;
  final String hint;
  final int value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          QadamIconBadge(icon: icon, size: 42),
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
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  hint,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.remove_rounded,
            onTap: onDecrement,
          ),
          SizedBox(
            width: 44,
            child: Center(
              child: Text(
                '$value',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? AppTheme.lavender : AppTheme.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
