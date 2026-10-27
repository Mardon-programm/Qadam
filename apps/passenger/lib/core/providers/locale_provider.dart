import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('ru')) {
    _loadLocale();
  }

  static const _localeKey = 'app_locale';
  static const _onboardingCompletedKey = 'onboarding_completed';

  bool _isFirstLaunch = true;

  bool get isFirstLaunch => _isFirstLaunch;

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(_localeKey) ?? 'ru';
    final onboardingCompleted = prefs.getBool(_onboardingCompletedKey) ?? false;
    _isFirstLaunch = !onboardingCompleted;
    state = Locale(localeCode);
  }

  Future<void> setLocale(String localeCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, localeCode);
    await prefs.setBool(_onboardingCompletedKey, true);
    _isFirstLaunch = false;
    state = Locale(localeCode);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
