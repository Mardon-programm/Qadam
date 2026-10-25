import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _ctrl = TextEditingController(text: '+996');
  bool _loading = false;
  String? _error;

  Future<void> _send() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(driverApiProvider);
      await api.requestOtp(_ctrl.text.trim());
      if (mounted) context.push('/auth/otp', extra: _ctrl.text.trim());
    } catch (_) {
      setState(() => _error = 'Не удалось отправить код');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_taxi,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text('Qadam Driver',
                    style: Theme.of(context).textTheme.headlineMedium),
              ]),
              const SizedBox(height: 48),
              Text('Войти как водитель',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              const Text('Введите номер телефона для получения кода',
                  style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 32),
              TextField(
                controller: _ctrl,
                keyboardType: TextInputType.phone,
                autofocus: true,
                style: Theme.of(context).textTheme.titleLarge,
                decoration: InputDecoration(
                  hintText: '+996 700 000 000',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _send,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Получить код'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
