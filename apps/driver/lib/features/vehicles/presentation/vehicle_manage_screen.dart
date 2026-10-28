import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

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
    setState(() {
      _loading = true;
      _error = null;
    });
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
      backgroundColor: AppTheme.surface,
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _VehiclesHeader(),
            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_vehicles.isNotEmpty) ...[
                      const QadamSectionLabel('Ваши автомобили'),
                      const SizedBox(height: 10),
                      ..._vehicles.map(
                        (v) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _VehicleCard(v: v as Map<String, dynamic>),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    QadamCard(
                      radius: 26,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Добавить автомобиль',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _makeController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Марка',
                              hintText: 'Toyota',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _modelController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Модель',
                              hintText: 'Camry',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _colorController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Цвет',
                              hintText: 'Белый',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _plateController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Номер',
                              hintText: '01KG123ABC',
                            ),
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
                            Text(
                              _error!,
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                color: AppTheme.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          QadamActionButton(
                            label: 'Добавить автомобиль',
                            loading: _loading,
                            onTap: _addVehicle,
                            icon: Icons.add_rounded,
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

class _VehiclesHeader extends StatelessWidget {
  const _VehiclesHeader();

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
            const Positioned.fill(child: QadamOrnament(opacity: 0.15)),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 52),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Material(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(context).maybePop(),
                            child: const SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const QadamTag(
                          label: 'АВТОПАРК',
                          color: Colors.white,
                          background: Color(0x33FFFFFF),
                          icon: Icons.directions_car_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Мои автомобили',
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
                      'Добавьте машину, чтобы принимать заказы',
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
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.v});
  final Map<String, dynamic> v;

  @override
  Widget build(BuildContext context) {
    final active = v['status'] == 'active';
    return QadamCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      borderColor:
          active ? AppTheme.primary.withValues(alpha: 0.35) : null,
      child: Row(
        children: [
          const QadamIconBadge(
            icon: Icons.directions_car_filled_rounded,
            size: 50,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${v['make']} ${v['model']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${v['plate_number']} • ${v['color']} • ${v['year']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (active)
            const QadamTag(
              label: 'Активный',
              color: AppTheme.success,
              background: AppTheme.mint,
            ),
        ],
      ),
    );
  }
}
