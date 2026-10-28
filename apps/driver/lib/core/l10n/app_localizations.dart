import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Minimal localisation wrapper for Qadam Driver.
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

  // ── Common Strings ───────────────────────────────────────────────────────
  String get appName => 'Qadam Driver';
  String get continueBtn => locale.languageCode == 'ky' ? 'Уланту' : 'Продолжить';
  String get cancel => locale.languageCode == 'ky' ? 'Жокко чыгаруу' : 'Отменить';
  String get confirm => locale.languageCode == 'ky' ? 'Ырастоо' : 'Подтвердить';
  String get save => locale.languageCode == 'ky' ? 'Сактоо' : 'Сохранить';
  String get back => locale.languageCode == 'ky' ? 'Артка' : 'Назад';
  String get error => locale.languageCode == 'ky' ? 'Ката' : 'Ошибка';
  String get loading => locale.languageCode == 'ky' ? 'Жүктөлүүдө' : 'Загрузка';
  String get retry => locale.languageCode == 'ky' ? 'Кайра аракет' : 'Повторить';
  String get logout => locale.languageCode == 'ky' ? 'Чыгуу' : 'Выйти';
  String get language => locale.languageCode == 'ky' ? 'Тил' : 'Язык';

  // ── Auth ────────────────────────────────────────────────────────────────
  String get loginAsDriver => locale.languageCode == 'ky' ? 'Айдоочу катары кирүү' : 'Войти как водитель';
  String get enterPhone => locale.languageCode == 'ky' ? 'Телефон номериңизди киргизиңиз' : 'Введите номер телефона';
  String get phoneHint => locale.languageCode == 'ky' ? 'Телефон номери' : 'Номер телефона';
  String get phonePlaceholder => '+996 700 000 000';
  String get getCode => locale.languageCode == 'ky' ? 'Код алуу' : 'Получить код';
  String get codeSendFailed => locale.languageCode == 'ky' ? 'Код жөнөтүү оңонушсуз болду' : 'Не удалось отправить код';
  String otpRateLimited(int minutes) => locale.languageCode == 'ky'
      ? 'Абдан көп аракет. $minutes мүнөттөн кийин кайталаңыз'
      : 'Слишком много попыток. Попробуйте через $minutes мин';
  String get networkError => locale.languageCode == 'ky'
      ? 'Интернет байланышы жок. Туташууну текшериңиз'
      : 'Нет соединения с интернетом. Проверьте связь';
  String get enterCode => locale.languageCode == 'ky' ? 'Кодду киргизиңиз' : 'Введите код';
  String get codeHint => locale.languageCode == 'ky' ? 'Алты цифрлуу код' : 'Шестизначный код';
  String get resendCode => locale.languageCode == 'ky' ? 'Кодду кайра жөнөтүү' : 'Отправить код повторно';
  String get invalidCode => locale.languageCode == 'ky' ? 'Код туура эмес' : 'Неверный код';

  // ── Dashboard ───────────────────────────────────────────────────────────
  String get youAreOnline => locale.languageCode == 'ky' ? 'Сиз онлайн' : 'Вы онлайн';
  String get youAreOffline => locale.languageCode == 'ky' ? 'Сиз офлайн' : 'Вы офлайн';
  String get receivingOrders => locale.languageCode == 'ky' ? 'Тапшырмаларды аласыз' : 'Получаете заказы';
  String get tapToStart => locale.languageCode == 'ky' ? 'Тапшырмаларды алуу үчүн басыңыз' : 'Нажмите, чтобы начать принимать заказы';
  String get walletBalance => locale.languageCode == 'ky' ? 'Кошелек балансы' : 'Баланс кошелька';
  String get details => locale.languageCode == 'ky' ? 'Толук маалымат' : 'Детали';
  String get incomingOrders => locale.languageCode == 'ky' ? 'Кирүү тапшырмалар' : 'Входящие заказы';
  String get loadError => locale.languageCode == 'ky' ? 'Жүктөө катасы' : 'Ошибка загрузки';
  String get newOrder => locale.languageCode == 'ky' ? 'Жаңы тапшырма' : 'Новый заказ';
  String get toPassenger => locale.languageCode == 'ky' ? 'Жүргүнчүгө чейин' : 'До пассажира';
  String get waitingOrders => locale.languageCode == 'ky' ? 'Тапшырмаларды күтөбүз…' : 'Ожидаем заказы…';
  String get enableOnline => locale.languageCode == 'ky' ? 'Тапшырмалар алуу үчүн «онлайн» статусын күйгүзүңүз' : 'Включите статус «онлайн», чтобы получать заказы';
  String get som => 'сом';

  // ── Profile ─────────────────────────────────────────────────────────────
  String get profile => locale.languageCode == 'ky' ? 'Профиль' : 'Профиль';
  String get driver => locale.languageCode == 'ky' ? 'Айдоочу' : 'Водитель';
  String get verified => locale.languageCode == 'ky' ? 'Тастыкталган' : 'Верифицирован';
  String get rejected => locale.languageCode == 'ky' ? 'Баш тартылган' : 'Отклонён';
  String get pending => locale.languageCode == 'ky' ? 'Текшерүүдө' : 'На проверке';
  String get online => locale.languageCode == 'ky' ? 'Онлайн' : 'Онлайн';
  String get offline => locale.languageCode == 'ky' ? 'Офлайн' : 'Офлайн';
  String get plan => locale.languageCode == 'ky' ? 'Тариф' : 'Тариф';
  String get flexCommission => locale.languageCode == 'ky' ? 'Flex (комиссиялуу)' : 'Flex (комиссионный)';
  String get change => locale.languageCode == 'ky' ? 'Өзгөртүү' : 'Сменить';
  String get myVehicles => locale.languageCode == 'ky' ? 'Менин унааларым' : 'Мои автомобили';
  String get documents => locale.languageCode == 'ky' ? 'Документтер' : 'Документы';
  String get ratingAndReviews => locale.languageCode == 'ky' ? 'Рейтинг жана пикирлер' : 'Рейтинг и отзывы';
  String get support => locale.languageCode == 'ky' ? 'Колдоо' : 'Поддержка';

  // ── Wallet ─────────────────────────────────────────────────────────────
  String get wallet => locale.languageCode == 'ky' ? 'Кошелек' : 'Кошелек';
  String get todayEarnings => locale.languageCode == 'ky' ? 'Бүгүнкү киреше' : 'Сегодняшний доход';
  String get weekEarnings => locale.languageCode == 'ky' ? 'Апталык киреше' : 'Недельный доход';
  String get monthEarnings => locale.languageCode == 'ky' ? 'Айлык киреше' : 'Месячный доход';
  String get transactions => locale.languageCode == 'ky' ? 'Транзакциялар' : 'Транзакции';
  String get payout => locale.languageCode == 'ky' ? 'Чыгаруу' : 'Вывод';
  String get pendingPayout => locale.languageCode == 'ky' ? 'Күтүлүүдө' : 'В ожидании';

  // ── Earnings ────────────────────────────────────────────────────────────
  String get earnings => locale.languageCode == 'ky' ? 'Киреше' : 'Доходы';
  String get totalRides => locale.languageCode == 'ky' ? 'Жалпы сапарлар' : 'Всего поездок';
  String get avgPerRide => locale.languageCode == 'ky' ? 'Бир сапарга орточо' : 'Среднее за поездку';
  String get rating => locale.languageCode == 'ky' ? 'Рейтинг' : 'Рейтинг';

  // ── Documents ────────────────────────────────────────────────────────────
  String get uploadDocument => locale.languageCode == 'ky' ? 'Документ жүктөө' : 'Загрузить документ';
  String get driversLicense => locale.languageCode == 'ky' ? 'Айдоочунун күбөлүгү' : 'Водительское удостоверение';
  String get vehicleRegistration => locale.languageCode == 'ky' ? 'Унаанын каттоо күбөлүгү' : 'Свидетельство о регистрации ТС';
  String get insurance => locale.languageCode == 'ky' ? 'Камсыздандыруу' : 'Страховка';
  String get status => locale.languageCode == 'ky' ? 'Статус' : 'Статус';
  String get uploaded => locale.languageCode == 'ky' ? 'Жүктөлгөн' : 'Загружен';
  String get notUploaded => locale.languageCode == 'ky' ? 'Жүктөлбөгөн' : 'Не загружен';
  String get underReview => locale.languageCode == 'ky' ? 'Текшерүүдө' : 'На проверке';
  String get approved => locale.languageCode == 'ky' ? 'Тастыкталган' : 'Одобрено';
  String get expired => locale.languageCode == 'ky' ? 'Мөөнөтү өткөн' : 'Истёк';

  // ── Vehicles ────────────────────────────────────────────────────────────
  String get myCars => locale.languageCode == 'ky' ? 'Менин унааларым' : 'Мои автомобили';
  String get addVehicle => locale.languageCode == 'ky' ? 'Унаа кошуу' : 'Добавить автомобиль';
  String get make => locale.languageCode == 'ky' ? 'Марка' : 'Марка';
  String get model => locale.languageCode == 'ky' ? 'Модель' : 'Модель';
  String get year => locale.languageCode == 'ky' ? 'Жыл' : 'Год';
  String get color => locale.languageCode == 'ky' ? 'Түс' : 'Цвет';
  String get plateNumber => locale.languageCode == 'ky' ? 'Мамлекеттик номер' : 'Госномер';
  String get vehicleType => locale.languageCode == 'ky' ? 'Унаа түрү' : 'Тип автомобиля';

  // ── Region (Intercity) ─────────────────────────────────────────────────
  String get intercity => locale.languageCode == 'ky' ? 'Шаарлар аралык' : 'Межгород';
  String get myTrips => locale.languageCode == 'ky' ? 'Менин сапарларым' : 'Мои рейсы';
  String get fromCity => locale.languageCode == 'ky' ? 'Шаардан' : 'От города';
  String get toCity => locale.languageCode == 'ky' ? 'Шаарга' : 'В город';
  String get departureTime => locale.languageCode == 'ky' ? 'Жөнөтүү убактысы' : 'Время отправления';
  String get seats => locale.languageCode == 'ky' ? 'Орундар' : 'Места';
  String get pricePerSeat => locale.languageCode == 'ky' ? 'Бир орун баасы' : 'Цена за место';
  String get tripCreated => locale.languageCode == 'ky' ? 'Сапар түзүлдү' : 'Рейс создан';
  String get noTrips => locale.languageCode == 'ky' ? 'Сапарлар жок' : 'Рейсов нет';
  String get createTrip => locale.languageCode == 'ky' ? 'Сапар түзүү' : 'Создать рейс';
  String get tripDate => locale.languageCode == 'ky' ? 'Сапар күнү' : 'Дата рейса';
  String get passengersOnBoard => locale.languageCode == 'ky' ? 'Жүргүнчүлөр саны' : 'Пассажиров на борту';
  String get tripStatus => locale.languageCode == 'ky' ? 'Сапар статусу' : 'Статус рейса';
  String get tripActive => locale.languageCode == 'ky' ? 'Активдүү' : 'Активен';
  String get tripCompleted => locale.languageCode == 'ky' ? 'Аякталган' : 'Завершен';
  String get tripCancelled => locale.languageCode == 'ky' ? 'Жокко чыгарылган' : 'Отменен';

  // ── Wallet ───────────────────────────────────────────────────────────────
  String get balance => locale.languageCode == 'ky' ? 'Баланс' : 'Баланс';
  String get available => locale.languageCode == 'ky' ? 'Жеткиликтүү' : 'Доступно';
  String get transactionsHistory => locale.languageCode == 'ky' ? 'Транзакция тарыхы' : 'История транзакций';
  String get payoutRequest => locale.languageCode == 'ky' ? 'Чыгаруу суранычы' : 'Запрос на вывод';
  String get payoutAmount => locale.languageCode == 'ky' ? 'Чыгаруу суммасы' : 'Сумма вывода';
  String get requestPayout => locale.languageCode == 'ky' ? 'Чыгаруу сурануу' : 'Запросить вывод';
  String get payoutProcessing => locale.languageCode == 'ky' ? 'Иштетүүдө' : 'В обработке';
  String get payoutCompleted => locale.languageCode == 'ky' ? 'Аякталды' : 'Выполнен';
  String get payoutFailed => locale.languageCode == 'ky' ? 'Оңонушсуз' : 'Неудачно';
  String get noTransactions => locale.languageCode == 'ky' ? 'Транзакциялар жок' : 'Транзакций нет';
  String get expenses => locale.languageCode == 'ky' ? 'Чыгымдар' : 'Расходы';
  String get commission => locale.languageCode == 'ky' ? 'Комиссия' : 'Комиссия';
  String get net => locale.languageCode == 'ky' ? 'Таза киреше' : 'Чистый доход';

  // ── Documents ────────────────────────────────────────────────────────────
  String get documentStatus => locale.languageCode == 'ky' ? 'Документ статусу' : 'Статус документа';
  String get upload => locale.languageCode == 'ky' ? 'Жүктөө' : 'Загрузить';
  String get chooseFile => locale.languageCode == 'ky' ? 'Файлды тандоо' : 'Выбрать файл';
  String get fileUploaded => locale.languageCode == 'ky' ? 'Файл жүктөлдү' : 'Файл загружен';
  String get uploadFailed => locale.languageCode == 'ky' ? 'Жүктөө оңонушсуз' : 'Загрузка не удалась';
  String get documentExpiring => locale.languageCode == 'ky' ? 'Документ мөөнөтү жакын' : 'Документ скоро истекает';
  String get documentExpired => locale.languageCode == 'ky' ? 'Документ мөөнөтү өткөн' : 'Документ истёк';
  String get renewDocument => locale.languageCode == 'ky' ? 'Документти жаңыртуу' : 'Обновить документ';
  String get insurancePolicy => locale.languageCode == 'ky' ? 'Камсыздандыруу полиси' : 'Страховой полис';
  String get allDocumentsUploaded => locale.languageCode == 'ky' ? 'Бардык документтер жүктөлдү' : 'Все документы загружены';
  String get uploadPending => locale.languageCode == 'ky' ? 'Жүктөө күтүлүүдө' : 'Ожидает загрузки';
  String get verificationRequired => locale.languageCode == 'ky' ? 'Текшерүү керек' : 'Требуется проверка';

  // ── Offers ───────────────────────────────────────────────────────────────
  String get accept => locale.languageCode == 'ky' ? 'Кабыл алуу' : 'Принять';
  String get reject => locale.languageCode == 'ky' ? 'Баш тартуу' : 'Отклонить';
  String get orderDetails => locale.languageCode == 'ky' ? 'Тапшырма маалыматтары' : 'Детали заказа';
  String get pickupLocation => locale.languageCode == 'ky' ? 'Чыгуу жери' : 'Место посадки';
  String get dropoffLocation => locale.languageCode == 'ky' ? 'Түшүү жери' : 'Место высадки';
  String get estimatedEarnings => locale.languageCode == 'ky' ? 'Болжолдуу киреше' : 'Ожидаемый доход';
  String get distance => locale.languageCode == 'ky' ? 'Аралыш' : 'Расстояние';
  String get duration => locale.languageCode == 'ky' ? 'Убакыт' : 'Время';
  String get passenger => locale.languageCode == 'ky' ? 'Жүргүнчү' : 'Пассажир';
  String get route => locale.languageCode == 'ky' ? 'Маршрут' : 'Маршрут';
  String get navigate => locale.languageCode == 'ky' ? 'Навигация' : 'Навигация';
  String get callPassenger => locale.languageCode == 'ky' ? 'Жүргүнчүгө чалуу' : 'Позвонить пассажиру';
  String get messagePassenger => locale.languageCode == 'ky' ? 'Жүргүнчүгө билдирүү' : 'Написать пассажиру';
  String get arrived => locale.languageCode == 'ky' ? 'Келдим' : 'Прибыл';
  String get startRide => locale.languageCode == 'ky' ? 'Сапарды баштоо' : 'Начать поездку';
  String get endRide => locale.languageCode == 'ky' ? 'Сапарды аяктоо' : 'Завершить поездку';
  String get waiting => locale.languageCode == 'ky' ? 'Күтүү' : 'Ожидание';
  String get waitingTime => locale.languageCode == 'ky' ? 'Күтүү убактысы' : 'Время ожидания';
  String get rideStarted => locale.languageCode == 'ky' ? 'Сапар башталды' : 'Поездка началась';
  String get rideEnded => locale.languageCode == 'ky' ? 'Сапар аякталды' : 'Поездка завершена';
  String get collectCash => locale.languageCode == 'ky' ? 'Накыты жыйноо' : 'Собрать наличные';
  String get paymentReceived => locale.languageCode == 'ky' ? 'Төлөө алынды' : 'Оплата получена';
  String get ratePassenger => locale.languageCode == 'ky' ? 'Жүргүнчүнү баалоо' : 'Оценить пассажира';
  String get leaveComment => locale.languageCode == 'ky' ? 'Пикир калтыруу' : 'Оставить комментарий';
  String get excellent => locale.languageCode == 'ky' ? 'Оксоз' : 'Отлично';
  String get good => locale.languageCode == 'ky' ? 'Жакшы' : 'Хорошо';
  String get average => locale.languageCode == 'ky' ? 'Орточо' : 'Средне';
  String get poor => locale.languageCode == 'ky' ? 'Начар' : 'Плохо';
  String get terrible => locale.languageCode == 'ky' ? 'Өтө начар' : 'Ужасно';
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
