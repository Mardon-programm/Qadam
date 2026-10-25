import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';

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
    'Бишкек', 'Ош', 'Джалал-Абад', 'Нарын',
    'Каракол', 'Токмок', 'Кант', 'Балыкчы',
  ];

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
      _departAt = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _create() async {
    if (_originCtrl.text.isEmpty ||
        _destCtrl.text.isEmpty ||
        _priceCtrl.text.isEmpty) return;

    setState(() => _saving = true);
    try {
      final api = ref.read(driverApiProvider);
      await api.createTrip({
        'origin_city': _originCtrl.text.trim().toLowerCase(),
        'destination_city': _destCtrl.text.trim().toLowerCase(),
        'depart_at': _departAt.toUtc().toIso8601String(),
        'price_per_seat': double.parse(_priceCtrl.text),
        'seat_count': _seats,
        if (_meetingCtrl.text.isNotEmpty) 'meeting_point': _meetingCtrl.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать рейс'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Маршрут', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Autocomplete<String>(
              optionsBuilder: (v) => _cities
                  .where((c) => c.toLowerCase().contains(v.text.toLowerCase())),
              onSelected: (v) => _originCtrl.text = v,
              fieldViewBuilder: (_, ctrl, fn, onSubmit) => TextField(
                controller: ctrl,
                focusNode: fn,
                decoration: const InputDecoration(hintText: 'Откуда'),
                onChanged: (v) => _originCtrl.text = v,
              ),
            ),
            const SizedBox(height: 8),
            Autocomplete<String>(
              optionsBuilder: (v) => _cities
                  .where((c) => c.toLowerCase().contains(v.text.toLowerCase())),
              onSelected: (v) => _destCtrl.text = v,
              fieldViewBuilder: (_, ctrl, fn, onSubmit) => TextField(
                controller: ctrl,
                focusNode: fn,
                decoration: const InputDecoration(hintText: 'Куда'),
                onChanged: (v) => _destCtrl.text = v,
              ),
            ),
            const SizedBox(height: 20),
            Text('Дата и время отправления',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDateTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: AppTheme.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      '${_departAt.day}.${_departAt.month}.${_departAt.year}  ${_departAt.hour}:${_departAt.minute.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Цена и места',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(hintText: 'Цена за место (сом)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Мест:'),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: _seats > 1
                      ? () => setState(() => _seats--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppTheme.primary,
                ),
                Text('$_seats',
                    style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  onPressed: _seats < 8
                      ? () => setState(() => _seats++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppTheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Место встречи (необязательно)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _meetingCtrl,
              decoration: const InputDecoration(
                  hintText: 'Например: АЗС Газпром у метро'),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saving ? null : _create,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Создать рейс'),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }
}
