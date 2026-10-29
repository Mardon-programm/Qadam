import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

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
];

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
        Row(
          children: kTariffs.map((t) {
            final selected = t.id == selectedId;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: t == kTariffs.last ? 0 : 10),
                child: GestureDetector(
                  onTap: () => onChanged(t.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                              Text(
                                t.subtitle,
                                maxLines: 1,
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
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
