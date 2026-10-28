import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

class NewCaseScreen extends ConsumerStatefulWidget {
  const NewCaseScreen({
    super.key,
    this.referenceType,
    this.referenceId,
  });

  final String? referenceType;
  final String? referenceId;

  @override
  ConsumerState<NewCaseScreen> createState() => _NewCaseScreenState();
}

class _NewCaseScreenState extends ConsumerState<NewCaseScreen> {
  final _subjectController = TextEditingController();
  final _descController = TextEditingController();
  String _caseType = 'general';
  bool _loading = false;

  static const _types = {
    'general': 'Общий вопрос',
    'payment_issue': 'Оплата',
    'driver_complaint': 'Жалоба',
    'trip_issue': 'Поездка',
    'account': 'Аккаунт',
    'other': 'Другое',
  };

  Future<void> _submit() async {
    if (_subjectController.text.isEmpty || _descController.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.openCase(
        caseType: _caseType,
        subject: _subjectController.text.trim(),
        description: _descController.text.trim(),
        referenceType: widget.referenceType,
        referenceId: widget.referenceId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Обращение отправлено'),
            backgroundColor: AppTheme.secondary,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          QadamBrandHeader(
            showBack: true,
            title: 'Новое обращение',
            subtitle: 'Опишите ситуацию — ответим в приложении',
            bottomRadius: 36,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Transform.translate(
                offset: const Offset(0, -26),
                child: QadamCard(
                  radius: 28,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const QadamSectionLabel('Тип обращения'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _types.entries.map((e) {
                          final selected = e.key == _caseType;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _caseType = e.key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                gradient: selected
                                    ? AppTheme.brandGradient
                                    : null,
                                color: selected
                                    ? null
                                    : AppTheme.surface,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: selected
                                      ? Colors.transparent
                                      : AppTheme.divider,
                                ),
                              ),
                              child: Text(
                                e.value,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 22),
                      const QadamSectionLabel('Тема'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _subjectController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Кратко опишите проблему',
                        ),
                      ),
                      const SizedBox(height: 20),
                      const QadamSectionLabel('Описание'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descController,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Подробно опишите ситуацию…',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      QadamActionButton(
                        label: 'Отправить',
                        loading: _loading,
                        onTap: _submit,
                        icon: Icons.send_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
