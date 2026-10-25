import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/api/models.dart';
import '../../../core/theme/app_theme.dart';

final _supportProvider = FutureProvider<List<SupportCase>>((ref) async {
  return ref.read(apiServiceProvider).getMyCases();
});

class SupportListScreen extends ConsumerWidget {
  const SupportListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesAsync = ref.watch(_supportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Поддержка'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/support/new'),
          ),
        ],
      ),
      body: casesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (cases) {
          if (cases.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.headset_mic_outlined,
                      size: 64,
                      color: AppTheme.textSecondary.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  const Text('Обращений нет',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => context.push('/support/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Создать обращение'),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cases.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _CaseCard(c: cases[i]),
          );
        },
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.c});
  final SupportCase c;

  Color _color() => switch (c.status) {
        'open' => AppTheme.warning,
        'in_progress' => AppTheme.primary,
        'resolved' => AppTheme.secondary,
        _ => AppTheme.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.subject,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _color().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  c.status,
                  style: TextStyle(
                      color: _color(),
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(c.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
          if (c.resolution != null) ...[
            const SizedBox(height: 8),
            Text('Ответ: ${c.resolution}',
                style: const TextStyle(
                    color: AppTheme.secondary, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
