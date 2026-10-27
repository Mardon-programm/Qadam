import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/theme/app_theme.dart';

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
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
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

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown == 0) {
        t.cancel();
      } else {
        if (mounted) setState(() => _countdown--);
      }
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length < 6) return;
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(driverApiProvider);
      final data = await api.verifyOtp(widget.phone, _code);
      await saveTokens(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      if (mounted) context.go('/dashboard');
    } catch (_) {
      setState(() => _error = 'Неверный код');
    } finally {
      if (mounted) setState(() => _loading = false);
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text('Код подтверждения',
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text('Отправлен на ${widget.phone}',
                style: const TextStyle(color: AppTheme.textSecondary)),
            if (widget.debugCode != null) ...[
              const SizedBox(height: 8),
              Text(
                'Демо-код: ${widget.debugCode}',
                style: const TextStyle(
                    color: AppTheme.secondary, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) => SizedBox(
                width: 48,
                child: TextField(
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: Theme.of(context).textTheme.headlineMedium,
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.primary, width: 2),
                    ),
                  ),
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 5) _focusNodes[i + 1].requestFocus();
                    if (v.isEmpty && i > 0) _focusNodes[i - 1].requestFocus();
                    if (_code.length == 6) _verify();
                  },
                ),
              )),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: AppTheme.error, fontSize: 13)),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _code.length == 6 && !_loading ? _verify : null,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Подтвердить'),
            ),
            const SizedBox(height: 16),
            Center(
              child: _countdown > 0
                  ? Text('Повторно через $_countdown с',
                      style: const TextStyle(color: AppTheme.textSecondary))
                  : TextButton(
                      onPressed: () async {
                        await ref.read(driverApiProvider).requestOtp(widget.phone);
                        setState(() => _countdown = 60);
                        _startTimer();
                      },
                      child: const Text('Отправить повторно'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
