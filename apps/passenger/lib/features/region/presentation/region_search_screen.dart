import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_button.dart';

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

  void _search() {
    final origin = _originController.text.trim().toLowerCase();
    final dest = _destController.text.trim().toLowerCase();
    if (origin.isEmpty || dest.isEmpty) return;
    context.push('/region/trips', extra: {'origin': origin, 'destination': dest});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Межгород')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _originController,
                    decoration: const InputDecoration(
                      hintText: 'Откуда',
                      prefixIcon: Icon(Icons.my_location,
                          color: AppTheme.primary, size: 20),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Divider(),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _destController,
                    decoration: const InputDecoration(
                      hintText: 'Куда',
                      prefixIcon:
                          Icon(Icons.location_on, color: AppTheme.error, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            QadamButton(
              label: 'Найти рейсы',
              onPressed: _search,
              icon: Icons.search,
            ),
            const SizedBox(height: 32),
            Text('Популярные направления',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _cities
                  .map((c) => ActionChip(
                        label: Text(c),
                        onPressed: () {
                          if (_originController.text.isEmpty) {
                            _originController.text = c;
                          } else {
                            _destController.text = c;
                          }
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
