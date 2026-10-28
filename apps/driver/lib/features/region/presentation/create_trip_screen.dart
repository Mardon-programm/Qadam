import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _meetingCtrl = TextEditingController();
  int _seats = 3;
  DateTime _departAt = DateTime.now().add(const Duration(hours: 2));
  bool _saving = false;

  static const _cities = [
    'Бишкек',
    'Ош',
    'Джалал-Абад',
    'Нарын',
    'Каракол',
    'Токмок',
    'Кант',
    'Балыкчы',
  ];

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    _priceCtrl.dispose();
    _meetingCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departAt),
    );
    if (time == null) return;
    setState(() {
      _departAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _create() async {
    if (_originCtrl.text.isEmpty ||
        _destCtrl.text.isEmpty ||
        _priceCtrl.text.isEmpty) {
      return;
    }

    setState(() => _saving = true);
    try {
      final api = ref.read(driverApiProvider);
      await api.createTrip({
        'origin_city': _originCtrl.text.trim().toLowerCase(),
        'destination_city': _destCtrl.text.trim().toLowerCase(),
        'depart_at': _departAt.toUtc().toIso8601String(),
        'price_per_seat': double.parse(_priceCtrl.text),
        'seat_count': _seats,
        if (_meetingCtrl.text.isNotEmpty)
          'meeting_point': _meetingCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Рейс создан!'),
            backgroundColor: AppTheme.secondary,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _departLabel {
    final d = _departAt;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day}.${d.month.toString().padLeft(2, '0')}.${d.year} · $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          const QadamBrandHeader(
            showBack: true,
            title: 'Создать рейс',
            subtitle: 'Пассажиры увидят рейс в поиске',
            bottomRadius: 36,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Transform.translate(
                  offset: const Offset(0, -26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      QadamCard(
                        radius: 26,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const QadamSectionLabel('Маршрут'),
                            const SizedBox(height: 12),
                            Autocomplete<String>(
                              optionsBuilder: (v) => _cities.where(
                                (c) => c
                                    .toLowerCase()
                                    .contains(v.text.toLowerCase()),
                              ),
                              onSelected: (v) => _originCtrl.text = v,
                              fieldViewBuilder: (_, ctrl, fn, onSubmit) =>
                                  TextField(
                                controller: ctrl,
                                focusNode: fn,
                                textCapitalization:
                                    TextCapitalization.words,
                                decoration: const InputDecoration(
                                  hintText: 'Откуда',
                                  prefixIcon:
                                      Icon(Icons.radio_button_checked_rounded),
                                ),
                                onChanged: (v) => _originCtrl.text = v,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Autocomplete<String>(
                              optionsBuilder: (v) => _cities.where(
                                (c) => c
                                    .toLowerCase()
                                    .contains(v.text.toLowerCase()),
                              ),
                              onSelected: (v) => _destCtrl.text = v,
                              fieldViewBuilder: (_, ctrl, fn, onSubmit) =>
                                  TextField(
                                controller: ctrl,
                                focusNode: fn,
                                textCapitalization:
                                    TextCapitalization.words,
                                decoration: const InputDecoration(
                                  hintText: 'Куда',
                                  prefixIcon: Icon(Icons.location_on_rounded),
                                ),
                                onChanged: (v) => _destCtrl.text = v,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      QadamCard(
                        radius: 26,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const QadamSectionLabel('Отправление'),
                            const SizedBox(height: 10),
                            Material(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _pickDateTime,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      const QadamIconBadge(
                                        icon: Icons.calendar_month_rounded,
                                        size: 40,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _departLabel,
                                          style: const TextStyle(
                                            fontFamily: 'Manrope',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const QadamSectionLabel('Цена и места'),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _priceCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Цена за место (сом)',
                                prefixIcon: Icon(Icons.payments_rounded),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const QadamIconBadge(
                                  icon: Icons.event_seat_rounded,
                                  size: 40,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Количество мест',
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                _SeatButton(
                                  icon: Icons.remove_rounded,
                                  onTap: _seats > 1
                                      ? () => setState(() => _seats--)
                                      : null,
                                ),
                                SizedBox(
                                  width: 42,
                                  child: Center(
                                    child: Text(
                                      '$_seats',
                                      style: const TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                _SeatButton(
                                  icon: Icons.add_rounded,
                                  onTap: _seats < 8
                                      ? () => setState(() => _seats++)
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      QadamCard(
                        radius: 26,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const QadamSectionLabel('Место встречи'),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _meetingCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Например: АЗС у восточного автовокзала',
                                prefixIcon: Icon(Icons.place_rounded),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      QadamActionButton(
                        label: 'Создать рейс',
                        loading: _saving,
                        onTap: _create,
                        icon: Icons.check_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatButton extends StatelessWidget {
  const _SeatButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? AppTheme.lavender : AppTheme.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
