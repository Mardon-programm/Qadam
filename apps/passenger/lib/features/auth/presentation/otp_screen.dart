import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/api/api_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone, this.debugCode});
  final String phone;

  /// Present only while the backend runs with the console SMS provider.
  final String? debugCode;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final code = widget.debugCode;
      if (code != null && code.length == 6) {
        for (var i = 0; i < 6; i++) {
          _controllers[i].text = code[i];
        }
      }
      _focusNodes[code != null && code.length == 6 ? 5 : 0].requestFocus();
    });
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown == 0) {
        t.cancel();
      } else {
        if (mounted) setState(() => _resendCountdown--);
      }
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length < 6) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final tokens = await api.verifyOtp(widget.phone, _code);
      await ref
          .read(authNotifierProvider.notifier)
          .signIn(tokens.accessToken, tokens.refreshToken);
      if (mounted) context.go('/home');
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      final failure = ApiFailure.from(e);
      final message = failure.isRateLimited
          ? l10n.otpRateLimited(failure.retryInMinutes)
          : l10n.invalidCode;
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final api = ref.read(apiServiceProvider);
    try {
      await api.requestOtp(widget.phone);
      setState(() => _resendCountdown = 60);
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final failure = ApiFailure.from(e);
      final message = failure.isRateLimited
          ? l10n.otpRateLimited(failure.retryInMinutes)
          : l10n.codeSendFailed;
      setState(() => _error = message);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
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
            showBack: true,
            title: l10n.enterCode,
            subtitle: locale.languageCode == 'ky'
                ? 'Код жөнөтүлдү: ${widget.phone}'
                : 'Код отправлен на ${widget.phone}',
            bottomRadius: 36,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Transform.translate(
                offset: const Offset(0, -26),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: AppTheme.floatShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.debugCode != null)
                        Align(
                          alignment: Alignment.center,
                          child: QadamTag(
                            label: 'Демо-код: ${widget.debugCode}',
                            color: AppTheme.secondary,
                            icon: Icons.bolt_rounded,
                          ),
                        ),
                      if (widget.debugCode != null)
                        const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (i) {
                          return SizedBox(
                            width: 48,
                            child: TextField(
                              controller: _controllers[i],
                              focusNode: _focusNodes[i],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: AppTheme.surface,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide:
                                      const BorderSide(color: AppTheme.divider),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide:
                                      const BorderSide(color: AppTheme.divider),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                      color: AppTheme.primary, width: 2),
                                ),
                              ),
                              onChanged: (v) {
                                if (v.isNotEmpty && i < 5) {
                                  _focusNodes[i + 1].requestFocus();
                                } else if (v.isEmpty && i > 0) {
                                  _focusNodes[i - 1].requestFocus();
                                }
                                if (_code.length == 6) _verify();
                              },
                            ),
                          );
                        }),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            color: AppTheme.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      QadamActionButton(
                        label: l10n.confirm,
                        onTap: _code.length == 6 ? _verify : null,
                        loading: _loading,
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: _resendCountdown > 0
                            ? Text(
                                locale.languageCode == 'ky'
                                    ? 'Кайра жөнөтүүгө $_resendCountdown секунд'
                                    : 'Отправить повторно через $_resendCountdown с',
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              )
                            : TextButton(
                                onPressed: _resend,
                                child: Text(l10n.resendCode),
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
