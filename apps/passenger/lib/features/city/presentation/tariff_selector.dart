import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class Tariff {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final double multiplier;
  const Tariff({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.multiplier,
  });
}

const kTariffs = [
  Tariff(
    id: 'economy',
    name: 'Эконом',
    subtitle: 'Самый доступный',
    icon: Icons.directions_car_rounded,
    multiplier: 1.0,
  ),
  Tariff(
    id: 'comfort',
    name: 'Комфорт',
    subtitle: 'Чуть просторнее и комфортнее',
    icon: Icons.airline_seat_recline_extra_rounded,
    multiplier: 1.25,
  ),
  Tariff(
    id: 'business',
    name: 'Премиум',
    subtitle: 'Комфортный класс',
    icon: Icons.workspace_premium_rounded,
    multiplier: 1.55,
  ),
  Tariff(
    id: 'minivan',
    name: 'Минивэн',
    subtitle: 'Для семьи и багажа',
    icon: Icons.people_alt_rounded,
    multiplier: 1.8,
  ),
  Tariff(
    id: 'vip',
    name: 'VIP',
    subtitle: 'Премиум-опыт',
    icon: Icons.emoji_events_rounded,
    multiplier: 2.3,
  ),
];

double tariffSurgeForId(String tariffId) {
  switch (tariffId) {
    case 'economy':
      return 1.0;
    case 'comfort':
      return 1.25;
    case 'business':
      return 1.55;
    case 'minivan':
      return 1.8;
    case 'vip':
      return 2.3;
    default:
      return 1.0;
  }
}

Tariff? tariffById(String tariffId) {
  for (final tariff in kTariffs) {
    if (tariff.id == tariffId) return tariff;
  }
  return null;
}

class TariffSelector extends StatelessWidget {
  const TariffSelector({
    super.key,
    required this.selectedId,
    required this.onChanged,
  });

  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            'Тариф',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kTariffs.length,
            padding: const EdgeInsets.only(right: 6),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final t = kTariffs[index];
              final selected = t.id == selectedId;
              return SizedBox(
                width: 180,
                child: GestureDetector(
                  onTap: () => onChanged(t.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      gradient: selected ? AppTheme.brandGradient : null,
                      color: selected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected ? Colors.transparent : AppTheme.divider,
                      ),
                      boxShadow: selected ? AppTheme.floatShadow : AppTheme.softShadow,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white.withValues(alpha: 0.22)
                                : AppTheme.lavender,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(t.icon,
                              color: selected ? Colors.white : AppTheme.primary,
                              size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                t.name,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: selected ? Colors.white : AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
