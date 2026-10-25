import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_button.dart';
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
      final booking = await notifier.createBooking(
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
    // We load trip details from cache or API
    // For simplicity we show a summary based on passed data
    return Scaffold(
      appBar: AppBar(
        title: const Text('Подтверждение брони'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                children: [
                  _CounterRow(
                    label: 'Пассажиры',
                    value: _passengers,
                    onDecrement:
                        _passengers > 1 ? () => setState(() => _passengers--) : null,
                    onIncrement: _passengers < 8
                        ? () => setState(() => _passengers++)
                        : null,
                  ),
                  const Divider(height: 24),
                  _CounterRow(
                    label: 'Багаж',
                    value: _baggage,
                    onDecrement:
                        _baggage > 0 ? () => setState(() => _baggage--) : null,
                    onIncrement:
                        _baggage < 4 ? () => setState(() => _baggage++) : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'После бронирования у вас есть 5 минут для оплаты. Неоплаченная бронь отменяется.',
                      style: TextStyle(
                          color: AppTheme.primary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            QadamButton(
              label: 'Забронировать',
              isLoading: _booking,
              onPressed: _book,
              icon: Icons.check,
            ),
            const SizedBox(height: 12),
            QadamButton(
              label: 'Назад',
              variant: QadamButtonVariant.text,
              onPressed: () => context.pop(),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final int value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.titleMedium)),
        IconButton(
          onPressed: onDecrement,
          icon: const Icon(Icons.remove_circle_outline),
          color: AppTheme.primary,
          disabledColor: AppTheme.divider,
        ),
        Text('$value',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        IconButton(
          onPressed: onIncrement,
          icon: const Icon(Icons.add_circle_outline),
          color: AppTheme.primary,
          disabledColor: AppTheme.divider,
        ),
      ],
    );
  }
}
