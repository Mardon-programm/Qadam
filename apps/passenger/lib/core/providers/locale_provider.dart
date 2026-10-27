import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Values read from SharedPreferences before the first frame.
class LocaleConfig {
  const LocaleConfig({this.localeCode = 'ru', this.onboardingCompleted = false});

  final String localeCode;
  final bool onboardingCompleted;
}

final localeConfigProvider = Provider<LocaleConfig>((ref) {
  return const LocaleConfig();
});

/// Reads the persisted locale/onboarding state. Called from `main()` so the
/// router already knows whether onboarding was completed when it is created;
/// reading it asynchronously made the language screen flash on every launch.
Future<LocaleConfig> loadLocaleConfig() async {
  final prefs = await SharedPreferences.getInstance();
  return LocaleConfig(
    localeCode: prefs.getString(LocaleNotifier.localeKey) ?? 'ru',
    onboardingCompleted:
        prefs.getBool(LocaleNotifier.onboardingCompletedKey) ?? false,
  );
}

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(LocaleConfig config)
      : _isFirstLaunch = !config.onboardingCompleted,
        super(Locale(config.localeCode));

  static const localeKey = 'app_locale';
  static const onboardingCompletedKey = 'onboarding_completed';

  bool _isFirstLaunch;

  bool get isFirstLaunch => _isFirstLaunch;

  Future<void> setLocale(String localeCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(localeKey, localeCode);
    await prefs.setBool(onboardingCompletedKey, true);
    _isFirstLaunch = false;
    state = Locale(localeCode);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier(ref.watch(localeConfigProvider));
});
