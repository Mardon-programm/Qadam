import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

class RegionSearchScreen extends StatefulWidget {
  const RegionSearchScreen({super.key});

  @override
  State<RegionSearchScreen> createState() => _RegionSearchScreenState();
}

class _RegionSearchScreenState extends State<RegionSearchScreen> {
  final _originController = TextEditingController();
  final _destController = TextEditingController();

  static const _cities = [
    'Бишкек',
    'Ош',
    'Джалал-Абад',
    'Нарын',
    'Каракол',
    'Токмок',
    'Кант',
    'Балыкчы',
    'Таш-Кумыр',
    'Кара-Балта',
  ];

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    super.dispose();
  }

  void _search() {
    final origin = _originController.text.trim().toLowerCase();
    final dest = _destController.text.trim().toLowerCase();
    if (origin.isEmpty || dest.isEmpty) return;
    context.push(
      '/region/trips',
      extra: {'origin': origin, 'destination': dest},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(36)),
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: QadamOrnament(opacity: 0.15),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 52),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const QadamWordmark(onDark: true),
                            const SizedBox(height: 26),
                            const Text(
                              'Межгород',
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
                              'Поездки между городами Кыргызстана',
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
            ),
            Transform.translate(
              offset: const Offset(0, -32),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    QadamCard(
                      radius: 26,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                        children: [
                          _PlaceField(
                            controller: _originController,
                            hint: 'Откуда',
                            dotColor: null,
                          ),
                          const Divider(height: 1, indent: 36),
                          _PlaceField(
                            controller: _destController,
                            hint: 'Куда',
                            dotColor: AppTheme.ink,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    QadamActionButton(
                      label: 'Найти рейсы',
                      onTap: _search,
                      icon: Icons.search_rounded,
                    ),
                    const SizedBox(height: 28),
                    const QadamSectionLabel('Популярные направления'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _cities
                          .map(
                            (c) => _CityChip(
                              label: c,
                              onTap: () {
                                setState(() {
                                  if (_originController.text.isEmpty) {
                                    _originController.text = c;
                                  } else {
                                    _destController.text = c;
                                  }
                                });
                              },
                            ),
                          )
                          .toList(),
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

class _PlaceField extends StatelessWidget {
  const _PlaceField({
    required this.controller,
    required this.hint,
    required this.dotColor,
  });

  final TextEditingController controller;
  final String hint;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            gradient: dotColor == null ? AppTheme.brandGradient : null,
            color: dotColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: dotColor == null ? Colors.transparent : AppTheme.ink,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _CityChip extends StatelessWidget {
  const _CityChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
