import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

final _docsProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(driverApiProvider).getDocuments();
});

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(_docsProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_docsProvider),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _DocsHeader(
                onAdd: () => _showAddDocSheet(context, ref),
              ),
            ),
            docsAsync.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: QadamCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const QadamIconBadge(
                            icon: Icons.wifi_off_rounded,
                            color: AppTheme.error,
                            size: 54,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Ошибка: $e',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              data: (docs) {
                if (docs.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyDocs(
                      onAdd: () => _showAddDocSheet(context, ref),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _DocCard(
                      doc: docs[i] as Map<String, dynamic>,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDocSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddDocSheet(onSaved: () => ref.invalidate(_docsProvider)),
    );
  }
}

class _DocsHeader extends StatelessWidget {
  const _DocsHeader({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
        child: Stack(
          children: [
            const Positioned.fill(child: QadamOrnament(opacity: 0.15)),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const QadamWordmark(onDark: true, subtitle: 'DRIVER'),
                        const Spacer(),
                        Material(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onAdd,
                            child: const SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Документы',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Для выхода на линию нужны 3 одобренных документа',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDocs extends StatelessWidget {
  const _EmptyDocs({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          QadamIconBadge(
            icon: Icons.description_rounded,
            color: AppTheme.primary,
            size: 84,
          ),
          const SizedBox(height: 20),
          const Text(
            'Документы не добавлены',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Загрузите водительское удостоверение, тех. паспорт и лицензию такси',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 22),
          QadamActionButton(
            label: 'Добавить документ',
            onTap: onAdd,
            icon: Icons.add_rounded,
          ),
        ],
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc});
  final Map<String, dynamic> doc;

  Color _statusColor() => switch (doc['status'] as String) {
        'approved' => AppTheme.success,
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
    return QadamCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          QadamIconBadge(
            icon: Icons.description_rounded,
            color: color,
            size: 46,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _docTypeLabel(),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (doc['expires_on'] != null)
                  Text(
                    'Истекает: ${doc['expires_on']}',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (doc['rejection_reason'] != null)
                  Text(
                    'Причина: ${doc['rejection_reason']}',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      color: AppTheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          QadamTag(label: _statusLabel(), color: color),
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
  void dispose() {
    _numCtrl.dispose();
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
              'Добавить документ',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              value: _docType,
              decoration: const InputDecoration(labelText: 'Тип документа'),
              items: _types.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(
                        e.value,
                        style: const TextStyle(fontFamily: 'Manrope'),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _docType = v!),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _numCtrl,
              decoration: const InputDecoration(
                labelText: 'Номер документа',
                hintText: 'Необязательно',
              ),
            ),
            const SizedBox(height: 22),
            QadamActionButton(
              label: 'Сохранить',
              loading: _saving,
              onTap: _save,
              icon: Icons.check_rounded,
            ),
            const SizedBox(height: 6),
            QadamActionButton(
              label: 'Отмена',
              style: QadamButtonStyle.link,
              height: 44,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
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
