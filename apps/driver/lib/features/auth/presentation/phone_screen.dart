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
  final _ctrl = TextEditingController(text: '+996');
  bool _loading = false;
  String? _error;

  Future<void> _send() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(driverApiProvider);
      final data = await api.requestOtp(_ctrl.text.trim());
      final debugCode = data['debug_code'] as String?;
      if (mounted) {
        context.push(
          '/auth/otp',
          extra: {'phone': _ctrl.text.trim(), 'code': debugCode},
        );
      }
    } catch (_) {
      setState(() => _error = AppLocalizations.of(context).codeSendFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QadamBrandHeader(
            title: l10n.loginAsDriver,
            subtitle: l10n.enterPhone,
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
                        controller: _ctrl,
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
                        label: l10n.getCode,
                        onTap: _send,
                        loading: _loading,
                        icon: Icons.arrow_forward_rounded,
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
