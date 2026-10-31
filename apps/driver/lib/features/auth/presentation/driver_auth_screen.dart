import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_error.dart';
import '../../../core/api/api_service.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

class DriverAuthScreen extends ConsumerStatefulWidget {
  const DriverAuthScreen({super.key});

  @override
  ConsumerState<DriverAuthScreen> createState() => _DriverAuthScreenState();
}

class _DriverAuthScreenState extends ConsumerState<DriverAuthScreen> {
  bool _isRegister = true;
  final _phoneCtrl = TextEditingController(text: '+996');
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  File? _photo;
  bool _obscure = true;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 512);
    if (x != null) setState(() => _photo = File(x.path));
  }

  Future<String?> _photoBase64() async {
    if (_photo == null) return null;
    final bytes = await _photo!.readAsBytes();
    return base64Encode(bytes);
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final pass = _passCtrl.text;
    if (phone.length < 9 || name.isEmpty || pass.length < 6) {
      setState(() => _error = 'Заполните все поля (пароль ≥6 символов)');
      return;
    }
    if (_isRegister && _photo == null) {
      setState(() => _error = 'Фото лица обязательно');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(driverApiProvider);
      final Map<String, dynamic> data;
      if (_isRegister) {
        final b64 = await _photoBase64();
        data = await api.registerDriver(
          phone: phone,
          fullName: name,
          password: pass,
          photoBase64: b64,
        );
      } else {
        data = await api.loginDriver(phone: phone, fullName: name, password: pass);
      }
      final access = data['access_token'] as String;
      final refresh = data['refresh_token'] as String;
      await saveTokens(access, refresh);
      if (mounted) context.go('/dashboard');
    } catch (e) {
      final failure = ApiFailure.from(e);
      setState(() => _error = failure.isNetwork ? 'Нет сети' : 'Ошибка: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QadamBrandHeader(
            title: _isRegister ? 'Регистрация водителя' : 'Вход водителя',
            subtitle: _isRegister
                ? 'ФИО, телефон и пароль'
                : 'Телефон, ФИО и пароль',
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
                      if (_isRegister) ...[
                        Center(
                          child: GestureDetector(
                            onTap: _pickPhoto,
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.divider, width: 2),
                                image: _photo != null
                                    ? DecorationImage(
                                        image: FileImage(_photo!), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: _photo == null
                                  ? const Icon(Icons.camera_alt_rounded,
                                      color: AppTheme.textSecondary, size: 32)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Фото лица (обязательно)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: '+996 XXX XXX XXX',
                          prefixIcon: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: Text('🇰🇬', style: TextStyle(fontSize: 22)),
                          ),
                          prefixIconConstraints:
                              BoxConstraints(minWidth: 0, minHeight: 0),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'ФИО',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Пароль',
                          prefixIcon: const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      QadamActionButton(
                        label: _isRegister ? 'Зарегистрироваться' : 'Войти',
                        onTap: _submit,
                        loading: _loading,
                        icon: Icons.arrow_forward_rounded,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => setState(() => _isRegister = !_isRegister),
                        child: Text(
                          _isRegister
                              ? 'Уже есть аккаунт? Войти'
                              : 'Нет аккаунта? Зарегистрироваться',
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w700,
                          ),
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
