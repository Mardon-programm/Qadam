import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

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
      backgroundColor: AppTheme.surface,
      body: meAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: QadamCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const QadamIconBadge(
                    icon: Icons.person_off_rounded,
                    color: AppTheme.error,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  QadamActionButton(
                    label: 'Повторить',
                    onTap: () => ref.invalidate(_meProvider),
                    style: QadamButtonStyle.soft,
                    height: 48,
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (me) => ListView(
          padding: EdgeInsets.zero,
          children: [
            _ProfileHeader(
              name: me['full_name'] as String? ?? l10n.driver,
              phone: me['phone'] as String? ?? '',
              profileAsync: profileAsync,
            ),
            Transform.translate(
              offset: const Offset(0, -34),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const _SubscriptionCard(),
                    const SizedBox(height: 16),
                    _SettingsSection(
                      title: 'Работа',
                      items: [
                        _Item(
                          icon: Icons.directions_car_rounded,
                          label: l10n.myVehicles,
                          onTap: () => context.push('/vehicles'),
                        ),
                        _Item(
                          icon: Icons.description_rounded,
                          label: l10n.documents,
                          onTap: () => context.push('/documents'),
                        ),
                        _Item(
                          icon: Icons.star_rounded,
                          label: l10n.ratingAndReviews,
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SettingsSection(
                      title: 'Аккаунт',
                      items: [
                        _Item(
                          icon: Icons.language_rounded,
                          label: l10n.language,
                          trailing: Text(
                            locale.languageCode == 'ky'
                                ? 'Кыргызча'
                                : 'Русский',
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                          onTap: () => _showLanguageDialog(context, ref),
                        ),
                        _Item(
                          icon: Icons.headset_mic_rounded,
                          label: l10n.support,
                          onTap: () {},
                        ),
                        _Item(
                          icon: Icons.info_rounded,
                          label: 'О приложении',
                          trailing: const Text(
                            '1.0.0',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    QadamActionButton(
                      label: l10n.logout,
                      onTap: () async {
                        await clearTokens();
                        if (context.mounted) context.go('/auth/phone');
                      },
                      style: QadamButtonStyle.danger,
                      icon: Icons.logout_rounded,
                      height: 54,
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => QadamSheet(
        padding: EdgeInsets.fromLTRB(
            24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Выберите язык / Тилди тандаңыз',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 18),
            _LanguageTile(
              flag: '🇷🇺',
              title: 'Русский',
              selected: ref.read(localeProvider).languageCode == 'ru',
              onTap: () {
                ref.read(localeProvider.notifier).setLocale('ru');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 10),
            _LanguageTile(
              flag: '🇰🇬',
              title: 'Кыргызча',
              selected: ref.read(localeProvider).languageCode == 'ky',
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

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.flag,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String flag;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.lavender : AppTheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.phone,
    required this.profileAsync,
  });

  final String name;
  final String phone;
  final AsyncValue<Map<String, dynamic>> profileAsync;

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
            const Positioned.fill(child: QadamOrnament(opacity: 0.16)),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 58),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const QadamWordmark(onDark: true, subtitle: 'DRIVER'),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: QadamAvatar(name: name, size: 66),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                phone,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    profileAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (profile) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusTag(
                            label: profile['verification_status'] as String,
                          ),
                          QadamTag(
                            label: profile['online_status'] == 'online'
                                ? 'На линии'
                                : 'Не на линии',
                            color: Colors.white,
                            background: const Color(0x33FFFFFF),
                            icon: Icons.circle,
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
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label});
  final String label;

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
    final approved = label == 'approved';
    return QadamTag(
      label: _text(context),
      color: Colors.white,
      background: approved ? const Color(0x3312B76A) : const Color(0x33FFFFFF),
      icon: approved
          ? Icons.verified_rounded
          : (label == 'rejected'
              ? Icons.cancel_rounded
              : Icons.hourglass_bottom_rounded),
    );
  }
}

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return QadamGradientCard(
      gradient: AppTheme.sunGradient,
      radius: 26,
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.ink.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppTheme.ink,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.plan,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    color: AppTheme.ink.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.flexCommission,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    color: AppTheme.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.ink.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              l10n.change,
              style: const TextStyle(
                fontFamily: 'Manrope',
                color: AppTheme.ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.items, this.title});
  final List<_Item> items;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: QadamSectionLabel(title!),
          ),
        ],
        QadamCard(
          radius: 24,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                items[i],
                if (i != items.length - 1)
                  const Divider(height: 1, indent: 68, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            QadamIconBadge(icon: icon, color: AppTheme.primary, size: 38),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
          ],
        ),
      ),
    );
  }
}
