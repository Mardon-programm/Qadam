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
            'Выберите тариф',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kTariffs.length,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final t = kTariffs[index];
              final selected = t.id == selectedId;
              return SizedBox(
                width: 172,
                child: GestureDetector(
                  onTap: () => onChanged(t.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF1F1F1F) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? const Color(0xFF1F1F1F) : const Color(0xFFE8E8E8),
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: selected
                          ? const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              )
                            ]
                          : const [
                              BoxShadow(
                                color: Color(0x0A000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              )
                            ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white.withValues(alpha: 0.12)
                                : const Color(0xFFF6F6F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            t.icon,
                            color: selected ? Colors.white : const Color(0xFF1F1F1F),
                            size: 20,
                          ),
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
                                  color: selected ? Colors.white : const Color(0xFF1F1F1F),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : const Color(0xFF6B6B6B),
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
