import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.requestOtp(_controller.text.trim());
      final debugCode = data['debug_code'] as String?;
      if (mounted) {
        context.push(
          '/auth/otp',
          extra: {'phone': _controller.text.trim(), 'code': debugCode},
        );
      }
    } catch (e) {
      setState(() => _error = AppLocalizations.of(context).codeSendFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = l10n.locale;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QadamBrandHeader(
            title: l10n.enterPhone,
            subtitle: locale.languageCode == 'ky'
                ? 'SMS код жөнөтөбүз'
                : 'Мы отправим SMS с кодом подтверждения',
            bottomRadius: 36,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Transform.translate(
                offset: const Offset(0, -26),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: AppTheme.floatShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _controller,
                        keyboardType: TextInputType.phone,
                        autofocus: true,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.phonePlaceholder,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: Text('🇰🇬', style: TextStyle(fontSize: 22)),
                          ),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 0, minHeight: 0),
                          errorText: _error,
                        ),
                      ),
                      const SizedBox(height: 18),
                      QadamActionButton(
                        label: l10n.sendCode,
                        onTap: _sendOtp,
                        loading: _loading,
                        icon: Icons.arrow_forward_rounded,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        locale.languageCode == 'ky'
                            ? '«Уланту» басуу менен Qadam колдонуу шарттарын кабыл аласыз'
                            : 'Нажимая «Продолжить», вы принимаете условия использования Qadam',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
