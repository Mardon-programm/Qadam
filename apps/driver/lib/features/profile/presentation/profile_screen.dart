import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/locale_provider.dart';

final _meProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(driverApiProvider).getMe();
});

final _profileProvider2 = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(driverApiProvider).getProfile();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(_meProvider);
    final profileAsync = ref.watch(_profileProvider2);
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
              CircleAvatar(
                radius: 44,
                backgroundColor: AppTheme.primary.withOpacity(0.1),
                child: Text(
                  (me['full_name'] as String? ?? 'Д').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.w700, color: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 12),
              Text(me['full_name'] as String? ?? l10n.driver,
                  style: Theme.of(context).textTheme.titleLarge),
              Text(me['phone'] as String? ?? '',
                  style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              // Status badge from profile
              profileAsync.when(
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
                data: (profile) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StatusBadge(label: profile['verification_status'] as String),
                    const SizedBox(width: 8),
                    _OnlineBadge(status: profile['online_status'] as String),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Subscription card
              _SubscriptionCard(),
              const SizedBox(height: 16),
              // Settings
              _SettingsSection(items: [
                _Item(
                  icon: Icons.directions_car,
                  label: l10n.myVehicles,
                  onTap: () {},
                ),
                _Item(
                  icon: Icons.description,
                  label: l10n.documents,
                  onTap: () => context.go('/documents'),
                ),
                _Item(
                  icon: Icons.star_outline,
                  label: l10n.ratingAndReviews,
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 16),
              _SettingsSection(items: [
                _Item(
                  icon: Icons.language,
                  label: l10n.language,
                  trailing: Text(locale.languageCode == 'ky' ? 'Кыргызча' : 'Русский'),
                  onTap: () => _showLanguageDialog(context, ref),
                ),
                _Item(
                  icon: Icons.headset_mic_outlined,
                  label: l10n.support,
                  onTap: () {},
                ),
                _Item(
                  icon: Icons.logout,
                  label: l10n.logout,
                  labelColor: AppTheme.error,
                  onTap: () async {
                    await clearTokens();
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});
  final String label;

  Color get _color => switch (label) {
        'approved' => AppTheme.secondary,
        'rejected' => AppTheme.error,
        'pending' => AppTheme.warning,
        _ => AppTheme.textSecondary,
      };

  String _text(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (label) {
        'approved' => l10n.verified,
        'rejected' => l10n.rejected,
        'pending' => l10n.pending,
        _ => label,
      };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(_text(context),
          style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isOnline = status == 'online';
    final color = isOnline ? AppTheme.secondary : AppTheme.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(isOnline ? l10n.online : l10n.offline,
            style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

class _SubscriptionCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C47FF), Color(0xFF4A2FD0)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.plan,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                Text(l10n.flexCommission,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: Text(l10n.change),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.items});
  final List<_Item> items;

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

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: labelColor ?? AppTheme.textSecondary, size: 22),
      title: Text(label,
          style: TextStyle(color: labelColor ?? AppTheme.textPrimary, fontSize: 15)),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios,
          size: 14, color: AppTheme.textSecondary),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      dense: true,
    );
  }
}
