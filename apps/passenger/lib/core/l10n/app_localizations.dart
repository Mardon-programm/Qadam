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
  String get codeSendFailed => locale.languageCode == 'ky' ? 'Код жөнөтүү оңонушсуз болду' : 'Не удалось отправить код';
  String get enterPhone => locale.languageCode == 'ky' ? 'Телефон номериңизди киргизиңиз' : 'Введите номер телефона';
  String get phonePlaceholder => '+996 700 000 000';
  String get som => locale.languageCode == 'ky' ? 'сом' : 'сом';
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
  String get paymentMethods => locale.languageCode == 'ky' ? 'Төлөө ыкмалары' : 'Способы оплаты';
  String get language => locale.languageCode == 'ky' ? 'Тил' : 'Язык';
  String get notifications => locale.languageCode == 'ky' ? 'Билдирүүлөр' : 'Уведомления';
  String get privacy => locale.languageCode == 'ky' ? 'Коопсуздук' : 'Конфиденциальность';
  String get help => locale.languageCode == 'ky' ? 'Жардам' : 'Справка';
  String get about => locale.languageCode == 'ky' ? 'Ишембик' : 'О приложении';
  String get confirm => locale.languageCode == 'ky' ? 'Ырастоо' : 'Подтвердить';
  String get resendCode => locale.languageCode == 'ky' ? 'Кодду кайра жөнөтүү' : 'Отправить код повторно';
  String get invalidCode => locale.languageCode == 'ky' ? 'Код туура эмес. Кайра аракет кылыңыз.' : 'Неверный код. Попробуйте ещё раз.';

  // ── City ────────────────────────────────────────────────────────────────
  String get yourLocation => locale.languageCode == 'ky' ? 'Сиздин жайгашкан жериңиз' : 'Ваше местоположение';
  String get whereTo => locale.languageCode == 'ky' ? 'Кайда барасыз?' : 'Куда едем?';
  String get needLocation => locale.languageCode == 'ky' ? 'Геолокацияга керек' : 'Нужен доступ к геолокации';
  String get locationError => locale.languageCode == 'ky' ? 'Жайгашууну алуу мүмкүн эмес' : 'Не удалось получить местоположение';
  String get retry => locale.languageCode == 'ky' ? 'Кайра аракет' : 'Повторить';
  String get orderRide => locale.languageCode == 'ky' ? 'Сапар заказ кылуу' : 'Заказать поездку';
  String get changeRoute => locale.languageCode == 'ky' ? 'Маршрутту өзгөртүү' : 'Изменить маршрут';
  String get pickupPoint => locale.languageCode == 'ky' ? 'Чыгуу жери' : 'Посадка';
  String get destination => locale.languageCode == 'ky' ? 'Барыш жери' : 'Назначение';
  String get rideCost => locale.languageCode == 'ky' ? 'Сапар баасы' : 'Стоимость поездки';
  String get surge => locale.languageCode == 'ky' ? 'Жогоруку сураныш' : 'Повышенный спрос';
  String get waitingForDriver => locale.languageCode == 'ky' ? 'Айдоочуну күтүү' : 'Ожидание водителя';
  String get driverArriving => locale.languageCode == 'ky' ? 'Айдоочу келатат' : 'Водитель прибывает';
  String get rideInProgress => locale.languageCode == 'ky' ? 'Сапар жүрүп жатат' : 'Поездка в процессе';

  // ── Region (Intercity) ─────────────────────────────────────────────────
  String get searchTrips => locale.languageCode == 'ky' ? 'Сапарларды издөө' : 'Поиск рейсов';
  String get from => locale.languageCode == 'ky' ? 'Шаардан' : 'Откуда';
  String get to => locale.languageCode == 'ky' ? 'Шаарга' : 'Куда';
  String get date => locale.languageCode == 'ky' ? 'Дата' : 'Дата';
  String get passengers => locale.languageCode == 'ky' ? 'Жүргүнчүлөр' : 'Пассажиры';
  String get search => locale.languageCode == 'ky' ? 'Издөө' : 'Поиск';
  String get availableTrips => locale.languageCode == 'ky' ? 'Жеткиликтүү сапарлар' : 'Доступные рейсы';
  String get noTripsFound => locale.languageCode == 'ky' ? 'Сапарлар табылган жок' : 'Рейсы не найдены';
  String get tryDifferentDate => locale.languageCode == 'ky' ? 'Башка күнү сынап көрүңүз' : 'Попробуйте другую дату';
  String get departure => locale.languageCode == 'ky' ? 'Жөнөтүү' : 'Отправление';
  String get arrival => locale.languageCode == 'ky' ? 'Келүү' : 'Прибытие';
  String get duration => locale.languageCode == 'ky' ? 'Убакыт' : 'Время в пути';
  String get seatsAvailable => locale.languageCode == 'ky' ? 'Орундар бар' : 'Места доступны';
  String get bookSeat => locale.languageCode == 'ky' ? 'Орун брондоо' : 'Забронировать место';
  String get selectSeats => locale.languageCode == 'ky' ? 'Орундарды тандоо' : 'Выберите места';
  String get seat => locale.languageCode == 'ky' ? 'Орун' : 'Место';
  String get bookingDetails => locale.languageCode == 'ky' ? 'Брондоо маалыматтары' : 'Детали бронирования';
  String get confirmBooking => locale.languageCode == 'ky' ? 'Брондоону ырастоо' : 'Подтвердить бронирование';
  String get total => locale.languageCode == 'ky' ? 'Жалпы' : 'Итого';
  String get paymentRequired => locale.languageCode == 'ky' ? 'Төлөө керек' : 'Требуется оплата';
  String get bookingConfirmed => locale.languageCode == 'ky' ? 'Брондоо ырасталды' : 'Бронирование подтверждено';
  String get ticket => locale.languageCode == 'ky' ? 'Билет' : 'Билет';

  // ── Support ─────────────────────────────────────────────────────────────
  String get supportCenter => locale.languageCode == 'ky' ? 'Колдоо борбору' : 'Центр поддержки';
  String get myRequests => locale.languageCode == 'ky' ? 'Менин арыздарым' : 'Мои обращения';
  String get newRequest => locale.languageCode == 'ky' ? 'Жаңы арыз' : 'Новое обращение';
  String get requestType => locale.languageCode == 'ky' ? 'Арыз түрү' : 'Тип обращения';
  String get describeIssue => locale.languageCode == 'ky' ? 'Маселени баяндаңыз' : 'Опишите проблему';
  String get submit => locale.languageCode == 'ky' ? 'Жөнөтүү' : 'Отправить';
  String get requestSent => locale.languageCode == 'ky' ? 'Арыз жөнөтүлдү' : 'Обращение отправлено';
  String get open => locale.languageCode == 'ky' ? 'Ачык' : 'Открыто';
  String get inProgress => locale.languageCode == 'ky' ? 'Жүрүп жатат' : 'В работе';
  String get resolved => locale.languageCode == 'ky' ? 'Чечилди' : 'Решено';
  String get closed => locale.languageCode == 'ky' ? 'Жабык' : 'Закрыто';
  String get rideRelated => locale.languageCode == 'ky' ? 'Сапар боюнча' : 'По поездке';
  String get paymentRelated => locale.languageCode == 'ky' ? 'Төлөө боюнча' : 'По оплате';
  String get accountRelated => locale.languageCode == 'ky' ? 'Эсеп боюнча' : 'По аккаунту';
  String get other => locale.languageCode == 'ky' ? 'Башка' : 'Другое';

  // ── History ─────────────────────────────────────────────────────────────
  String get rideHistory => locale.languageCode == 'ky' ? 'Сапар тарыхы' : 'История поездок';
  String get noRides => locale.languageCode == 'ky' ? 'Сапарлар жок' : 'Поездок нет';
  String get upcoming => locale.languageCode == 'ky' ? 'Келе жаткан' : 'Предстоящие';
  String get completed => locale.languageCode == 'ky' ? 'Аякталган' : 'Завершенные';
  String get cancelled => locale.languageCode == 'ky' ? 'Жокко чыгарылган' : 'Отмененные';
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
