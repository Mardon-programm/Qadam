import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Minimal localisation wrapper.
/// Replace with flutter_gen / arb files as the project grows.
class AppLocalizations {
  AppLocalizations(this.locale);
  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const delegate = _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    _AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const supportedLocales = [
    Locale('ru'),
    Locale('ky'),
  ];

  // ── Strings ───────────────────────────────────────────────────────────────

  String get appName => 'Qadam';
  String get continueBtn => locale.languageCode == 'ky' ? 'Уланту' : 'Продолжить';
  String get phoneHint => locale.languageCode == 'ky' ? 'Телефон номери' : 'Номер телефона';
  String get enterCode => locale.languageCode == 'ky' ? 'Кодду киргизиңиз' : 'Введите код';
  String get sendCode => locale.languageCode == 'ky' ? 'Код жөнөтүү' : 'Отправить код';
  String get whereToGo => locale.languageCode == 'ky' ? 'Кайда барасыз?' : 'Куда едем?';
  String get pickup => locale.languageCode == 'ky' ? 'Чыгуу жери' : 'Откуда';
  String get dropoff => locale.languageCode == 'ky' ? 'Барыш жери' : 'Куда';
  String get book => locale.languageCode == 'ky' ? 'Брондоо' : 'Забронировать';
  String get cancel => locale.languageCode == 'ky' ? 'Жокко чыгаруу' : 'Отменить';
  String get history => locale.languageCode == 'ky' ? 'Тарых' : 'История';
  String get support => locale.languageCode == 'ky' ? 'Колдоо' : 'Поддержка';
  String get profile => locale.languageCode == 'ky' ? 'Профиль' : 'Профиль';
  String get intercity => locale.languageCode == 'ky' ? 'Шаарлар аралык' : 'Межгород';
  String get cityRide => locale.languageCode == 'ky' ? 'Такси' : 'Такси';
  String get priceLabel => locale.languageCode == 'ky' ? 'Баасы' : 'Стоимость';
  String get kgs => 'сом';
  String get driverOnWay => locale.languageCode == 'ky' ? 'Айдоочу жолдо' : 'Водитель едет';
  String get rideCompleted => locale.languageCode == 'ky' ? 'Жол аяктады' : 'Поездка завершена';
  String get rideCancelled => locale.languageCode == 'ky' ? 'Жол жокко чыгарылды' : 'Поездка отменена';
  String get noRidesYet => locale.languageCode == 'ky' ? 'Жолдор жок' : 'Поездок пока нет';
  String get submitCase => locale.languageCode == 'ky' ? 'Кайрылуу жөнөтүү' : 'Отправить обращение';
  String get logout => locale.languageCode == 'ky' ? 'Чыгуу' : 'Выйти';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ru', 'ky'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
