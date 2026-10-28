import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

final _paymentMethodsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api
      .get('/payments/methods')
      .then((r) => List<Map<String, dynamic>>.from(r.data['methods'] ?? []));
});

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  bool _adding = false;

  Future<void> _addCard() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AddCardSheet(),
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
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QadamSheet(
        padding: EdgeInsets.fromLTRB(
            24, 12, 24, MediaQuery.of(ctx).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.error,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Удалить карту?',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Вы уверены, что хотите удалить этот способ оплаты?',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            QadamActionButton(
              label: 'Удалить',
              onTap: () => Navigator.pop(ctx, true),
              style: QadamButtonStyle.danger,
            ),
            const SizedBox(height: 8),
            QadamActionButton(
              label: 'Отмена',
              onTap: () => Navigator.pop(ctx, false),
              style: QadamButtonStyle.link,
              height: 48,
            ),
          ],
        ),
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
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          const QadamBrandHeader(
            showBack: true,
            title: 'Способы оплаты',
            subtitle: 'Карты и наличные для поездок',
            bottomRadius: 36,
          ),
          Expanded(
            child: methodsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Ошибка: $e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              data: (methods) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Transform.translate(
                    offset: const Offset(0, -26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (methods.isEmpty)
                          const _EmptyCards()
                        else
                          ...methods.map(
                            (method) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PaymentMethodCard(
                                method: method,
                                onRemove: () {
                                  final id = method['id'];
                                  if (id != null) _removeMethod('$id');
                                },
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        QadamActionButton(
                          label: 'Добавить карту',
                          icon: Icons.add_card_rounded,
                          onTap: _addCard,
                          loading: _adding,
                        ),
                        const SizedBox(height: 18),
                        QadamCard(
                          padding: const EdgeInsets.all(16),
                          color: AppTheme.lavender,
                          borderColor: Colors.transparent,
                          child: const Row(
                            children: [
                              Icon(
                                Icons.lock_rounded,
                                color: AppTheme.primary,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Данные карт защищены и шифруются. Мы не храним полные номера карт.',
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    color: AppTheme.primary,
                                    fontSize: 13,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCards extends StatelessWidget {
  const _EmptyCards();

  @override
  Widget build(BuildContext context) {
    return QadamCard(
      radius: 28,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
      child: Column(
        children: [
          QadamIconBadge(
            icon: Icons.credit_card_off_rounded,
            color: AppTheme.primary,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Нет сохранённых карт',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'В городе можно платить наличными водителю — карта нужна для межгорода',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
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

    return QadamGradientCard(
      gradient: AppTheme.deepGradient,
      radius: 24,
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.credit_card_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$brand •••• $last4',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      const QadamTag(
                        label: 'Основная',
                        color: Color(0xFF8BFFE4),
                        background: Color(0x1F8BFFE4),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  method['expires'] ?? '',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddCardSheet extends StatefulWidget {
  const _AddCardSheet();

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: QadamSheet(
        padding: EdgeInsets.fromLTRB(
            24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Добавить карту',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Данные передаются в зашифрованном виде',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _cardController,
              keyboardType: TextInputType.number,
              maxLength: 19,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
              ],
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 17,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                labelText: 'Номер карты',
                hintText: '1234 5678 9012 3456',
                counterText: '',
                prefixIcon: Icon(Icons.credit_card_rounded),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _expiryController,
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Срок',
                      hintText: 'MM/YY',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _cvvController,
                    keyboardType: TextInputType.number,
                    maxLength: 3,
                    obscureText: true,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      hintText: '123',
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            QadamActionButton(
              label: 'Добавить',
              icon: Icons.check_rounded,
              onTap: () {
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
            ),
            const SizedBox(height: 8),
            QadamActionButton(
              label: 'Отмена',
              style: QadamButtonStyle.link,
              height: 44,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
