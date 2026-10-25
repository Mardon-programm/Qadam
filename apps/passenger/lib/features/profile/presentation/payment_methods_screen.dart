import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_button.dart';

final _paymentMethodsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.get('/payments/methods')
      .then((r) => List<Map<String, dynamic>>.from(r.data['methods'] ?? []));
});

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  bool _adding = false;

  Future<void> _addCard() async {
    // In production, this would integrate with a payment provider SDK
    // For now, show a placeholder dialog
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => const _AddCardDialog(),
    );

    if (result != null && mounted) {
      setState(() => _adding = true);
      try {
        final api = ref.read(apiServiceProvider);
        await api.post('/payments/methods', data: result);
        ref.invalidate(_paymentMethodsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Карта добавлена'),
              backgroundColor: AppTheme.secondary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _adding = false);
      }
    }
  }

  Future<void> _removeMethod(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить карту?'),
        content: const Text('Вы уверены, что хотите удалить этот способ оплаты?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final api = ref.read(apiServiceProvider);
        await api.delete('/payments/methods/$id');
        ref.invalidate(_paymentMethodsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Карта удалена')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final methodsAsync = ref.watch(_paymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Способы оплаты'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: methodsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (methods) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (methods.isEmpty)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 64),
                    Icon(
                      Icons.credit_card_outlined,
                      size: 64,
                      color: AppTheme.textSecondary.withOpacity(0.4),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Нет сохраненных карт',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              )
            else
              ...methods.map((method) => _PaymentMethodCard(
                method: method,
                onRemove: () => _removeMethod(method['id']),
              )),
            const SizedBox(height: 16),
            QadamButton(
              label: 'Добавить карту',
              icon: Icons.add,
              variant: QadamButtonVariant.outline,
              isLoading: _adding,
              onPressed: _addCard,
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
                  Icon(Icons.security, color: AppTheme.primary, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Все данные карт защищены и шифруются. Мы не храним полные номера карт.',
                      style: TextStyle(color: AppTheme.primary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.method,
    required this.onRemove,
  });

  final Map<String, dynamic> method;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final last4 = method['last4'] ?? '****';
    final brand = method['brand'] ?? 'card';
    final isDefault = method['is_default'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefault ? AppTheme.primary : AppTheme.divider,
          width: isDefault ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.credit_card, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$brand •••• $last4',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Основная',
                          style: TextStyle(
                            color: AppTheme.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  method['expires'] ?? '',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 22),
          ),
        ],
      ),
    );
  }
}

class _AddCardDialog extends StatefulWidget {
  const _AddCardDialog();

  @override
  State<_AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends State<_AddCardDialog> {
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  @override
  void dispose() {
    _cardController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить карту'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _cardController,
            decoration: const InputDecoration(
              labelText: 'Номер карты',
              hintText: '1234 5678 9012 3456',
            ),
            keyboardType: TextInputType.number,
            maxLength: 19,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _expiryController,
                  decoration: const InputDecoration(
                    labelText: 'Срок',
                    hintText: 'MM/YY',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _cvvController,
                  decoration: const InputDecoration(
                    labelText: 'CVV',
                    hintText: '123',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                  obscureText: true,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () {
            if (_cardController.text.isNotEmpty &&
                _expiryController.text.isNotEmpty &&
                _cvvController.text.isNotEmpty) {
              Navigator.pop(context, {
                'card_number': _cardController.text,
                'expiry': _expiryController.text,
                'cvv': _cvvController.text,
              });
            }
          },
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}
