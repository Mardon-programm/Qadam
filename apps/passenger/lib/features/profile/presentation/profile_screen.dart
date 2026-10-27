import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/locale_provider.dart';

final _meProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(apiServiceProvider).getMe();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(_meProvider);
    final locale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile)),
      body: meAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (me) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Avatar
              CircleAvatar(
                radius: 44,
                backgroundColor: AppTheme.primary.withOpacity(0.1),
                child: Text(
                  (me['full_name'] as String? ?? me['phone'] as String? ?? '?')
                      .substring(0, 1)
                      .toUpperCase(),
                  style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                me['full_name'] as String? ?? 'Пользователь',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                me['phone'] as String? ?? '',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              // Settings section
              _SettingsSection(items: [
                _SettingsItem(
                  icon: Icons.payment,
                  label: l10n.paymentMethods,
                  onTap: () => context.push('/profile/payment-methods'),
                ),
                _SettingsItem(
                  icon: Icons.language,
                  label: l10n.language,
                  trailing: Text(locale.languageCode == 'ky' ? 'Кыргызча' : 'Русский'),
                  onTap: () => _showLanguageDialog(context, ref),
                ),
                _SettingsItem(
                  icon: Icons.notifications_outlined,
                  label: l10n.notifications,
                  onTap: () {},
                ),
                _SettingsItem(
                  icon: Icons.shield_outlined,
                  label: l10n.privacy,
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 16),
              _SettingsSection(items: [
                _SettingsItem(
                  icon: Icons.help_outline,
                  label: l10n.help,
                  onTap: () => context.push('/support/new'),
                ),
                _SettingsItem(
                  icon: Icons.info_outline,
                  label: l10n.about,
                  trailing: const Text('1.0.0',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 16),
              _SettingsSection(items: [
                _SettingsItem(
                  icon: Icons.logout,
                  label: l10n.logout,
                  labelColor: AppTheme.error,
                  onTap: () async {
                    await ref
                        .read(authNotifierProvider.notifier)
                        .signOut();
                    if (context.mounted) context.go('/auth/phone');
                  },
                ),
              ]),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите язык / Тилди тандаңыз'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Русский'),
              onTap: () {
                ref.read(localeProvider.notifier).setLocale('ru');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Кыргызча'),
              onTap: () {
                ref.read(localeProvider.notifier).setLocale('ky');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.items});
  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: items
            .map((item) => item)
            .expand((item) => [
                  item,
                  if (item != items.last)
                    const Divider(height: 1, indent: 56),
                ])
            .toList(),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: labelColor ?? AppTheme.textSecondary, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: labelColor ?? AppTheme.textPrimary,
          fontSize: 15,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      dense: true,
    );
  }
}
