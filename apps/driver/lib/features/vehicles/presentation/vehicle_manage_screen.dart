import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';

class VehicleManageScreen extends ConsumerStatefulWidget {
  const VehicleManageScreen({super.key});

  @override
  ConsumerState<VehicleManageScreen> createState() => _VehicleManageScreenState();
}

class _VehicleManageScreenState extends ConsumerState<VehicleManageScreen> {
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  final _yearController = TextEditingController();
  final _seatsController = TextEditingController(text: '4');

  bool _loading = false;
  String? _error;
  List<dynamic> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    try {
      final api = ref.read(driverApiProvider);
      final result = await api.getVehicles();
      if (mounted) setState(() => _vehicles = result);
    } catch (e) {
      if (mounted) setState(() => _error = 'Ошибка загрузки');
    }
  }

  Future<void> _addVehicle() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(driverApiProvider);
      await api.addVehicle({
        'make': _makeController.text.trim(),
        'model': _modelController.text.trim(),
        'color': _colorController.text.trim(),
        'plate_number': _plateController.text.trim().toUpperCase(),
        'year': int.parse(_yearController.text.trim()),
        'seats': int.parse(_seatsController.text.trim()),
      });

      _makeController.clear();
      _modelController.clear();
      _colorController.clear();
      _plateController.clear();
      _yearController.clear();
      _seatsController.text = '4';

      await _loadVehicles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Автомобиль добавлен')),
        );
      }
    } catch (e) {
      setState(() => _error = 'Ошибка добавления: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои автомобили'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Existing vehicles
            if (_vehicles.isNotEmpty) ...[
              Text('Ваши автомобили',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ..._vehicles.map((v) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.directions_car, size: 32),
                      title: Text('${v['make']} ${v['model']}'),
                      subtitle: Text('${v['plate_number']} • ${v['color']} • ${v['year']}'),
                      trailing: v['status'] == 'active'
                          ? const Chip(
                              label: Text('Активный'),
                              backgroundColor: AppTheme.success,
                            )
                          : null,
                    ),
                  )),
              const SizedBox(height: 24),
            ],

            // Add vehicle form
            Text('Добавить автомобиль',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _makeController,
              decoration: const InputDecoration(
                labelText: 'Марка',
                hintText: 'Toyota',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Модель',
                hintText: 'Camry',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _colorController,
              decoration: const InputDecoration(
                labelText: 'Цвет',
                hintText: 'Белый',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _plateController,
              decoration: const InputDecoration(
                labelText: 'Номер',
                hintText: '01KG123ABC',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _yearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Год',
                      hintText: '2020',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _seatsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Мест',
                      hintText: '4',
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: AppTheme.error)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _addVehicle,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Добавить автомобиль'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _yearController.dispose();
    _seatsController.dispose();
    super.dispose();
  }
}
