import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_button.dart';

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
    'payment_issue': 'Проблема с оплатой',
    'driver_complaint': 'Жалоба на водителя',
    'trip_issue': 'Проблема с поездкой',
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
      appBar: AppBar(
        title: const Text('Новое обращение'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тип обращения',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.entries.map((e) {
                final selected = e.key == _caseType;
                return ChoiceChip(
                  label: Text(e.value),
                  selected: selected,
                  onSelected: (_) => setState(() => _caseType = e.key),
                  selectedColor: AppTheme.primary.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: selected ? AppTheme.primary : AppTheme.textSecondary,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('Тема', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _subjectController,
              decoration:
                  const InputDecoration(hintText: 'Кратко опишите проблему'),
            ),
            const SizedBox(height: 16),
            Text('Описание', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Подробно опишите ситуацию…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),
            QadamButton(
              label: 'Отправить',
              isLoading: _loading,
              onPressed: _submit,
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }
}
