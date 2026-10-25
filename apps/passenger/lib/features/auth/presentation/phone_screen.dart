import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_button.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _controller = TextEditingController(text: '+996');
  bool _loading = false;
  String? _error;

  Future<void> _sendOtp() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider);
      await api.requestOtp(_controller.text.trim());
      if (mounted) context.push('/auth/otp', extra: _controller.text.trim());
    } catch (e) {
      setState(() => _error = 'Не удалось отправить код. Проверьте номер.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              // Logo
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.directions_car,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text('Qadam',
                      style: Theme.of(context).textTheme.headlineMedium),
                ],
              ),
              const SizedBox(height: 48),
              Text(
                'Введите номер телефона',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Мы отправим SMS с кодом подтверждения',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                autofocus: true,
                style: Theme.of(context).textTheme.titleLarge,
                decoration: InputDecoration(
                  hintText: '+996 700 000 000',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('🇰🇬', style: TextStyle(fontSize: 20)),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 24),
              QadamButton(
                label: l10n.sendCode,
                isLoading: _loading,
                onPressed: _sendOtp,
              ),
              const Spacer(),
              Center(
                child: Text(
                  'Nажимая «Продолжить», вы принимаете\nусловия использования Qadam',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
