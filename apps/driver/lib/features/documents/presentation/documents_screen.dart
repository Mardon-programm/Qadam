import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';

final _docsProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(driverApiProvider).getDocuments();
});

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(_docsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Документы'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDocSheet(context, ref),
          ),
        ],
      ),
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (docs) {
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_outlined,
                      size: 64,
                      color: AppTheme.textSecondary.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  const Text('Документы не добавлены',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => _showAddDocSheet(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить документ'),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) =>
                _DocCard(doc: docs[i] as Map<String, dynamic>),
          );
        },
      ),
    );
  }

  void _showAddDocSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddDocSheet(onSaved: () => ref.invalidate(_docsProvider)),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc});
  final Map<String, dynamic> doc;

  Color _statusColor() => switch (doc['status'] as String) {
        'approved' => AppTheme.secondary,
        'rejected' => AppTheme.error,
        _ => AppTheme.warning,
      };

  String _statusLabel() => switch (doc['status'] as String) {
        'approved' => 'Одобрен',
        'rejected' => 'Отклонён',
        _ => 'На проверке',
      };

  String _docTypeLabel() => switch (doc['doc_type'] as String) {
        'driver_license' => 'Водительское удостоверение',
        'vehicle_registration' => 'Тех. паспорт',
        'taxi_license' => 'Лицензия такси',
        'insurance' => 'Страховка',
        'passport' => 'Паспорт',
        _ => doc['doc_type'] as String,
      };

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.description, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_docTypeLabel(),
                    style: Theme.of(context).textTheme.titleMedium),
                if (doc['expires_on'] != null)
                  Text('Истекает: ${doc['expires_on']}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                if (doc['rejection_reason'] != null)
                  Text('Причина: ${doc['rejection_reason']}',
                      style: const TextStyle(
                          color: AppTheme.error, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusLabel(),
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddDocSheet extends ConsumerStatefulWidget {
  const _AddDocSheet({required this.onSaved});
  final VoidCallback onSaved;

  @override
  ConsumerState<_AddDocSheet> createState() => _AddDocSheetState();
}

class _AddDocSheetState extends ConsumerState<_AddDocSheet> {
  String _docType = 'driver_license';
  final _numCtrl = TextEditingController();
  bool _saving = false;

  static const _types = {
    'driver_license': 'Водительское удостоверение',
    'vehicle_registration': 'Тех. паспорт',
    'taxi_license': 'Лицензия такси',
    'insurance': 'Страховка',
    'passport': 'Паспорт',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Добавить документ',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _docType,
            decoration: const InputDecoration(labelText: 'Тип документа'),
            items: _types.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _docType = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _numCtrl,
            decoration: const InputDecoration(
                hintText: 'Номер документа (необязательно)'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(driverApiProvider);
      await api.uploadDocument({
        'doc_type': _docType,
        if (_numCtrl.text.isNotEmpty) 'document_number': _numCtrl.text.trim(),
      });
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
