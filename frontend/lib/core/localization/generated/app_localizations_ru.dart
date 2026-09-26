// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'BarakaBozor';

  @override
  String get customerLoginTitle => 'Вход';

  @override
  String get customerLoginIntro =>
      'Введите номер телефона, мы отправим код для входа';

  @override
  String get phoneLabel => 'Номер телефона';

  @override
  String get phoneHint => '90 123 45 67';

  @override
  String get phoneInvalid => 'Введите 9 цифр номера';

  @override
  String get continueButton => 'Продолжить';

  @override
  String get codeSentTelegram => 'Код отправлен в Telegram';

  @override
  String get codeSentSms => 'Код отправлен по SMS';

  @override
  String get codeSentGeneric => 'Код отправлен';

  @override
  String get codeLabel => 'Код для входа';

  @override
  String get codeInvalidFormat => 'Введите код из 6 цифр';

  @override
  String get verifyButton => 'Подтвердить';

  @override
  String get resendCode => 'Отправить код ещё раз';

  @override
  String resendIn(int seconds) {
    return 'Отправить ещё раз через $seconds с';
  }

  @override
  String get changePhone => 'Изменить номер';

  @override
  String codeSentToPhone(String phone) {
    return 'Код отправлен на номер $phone';
  }

  @override
  String get customerModeIntro =>
      'Чтобы войти в режим клиента, введите код, отправленный на ваш номер';

  @override
  String get cancelButton => 'Отмена';

  @override
  String get requestCodeButton => 'Запросить код';

  @override
  String get wrongSurfaceTitle => 'Отсюда войти нельзя';

  @override
  String get staffLoginTitle => 'Вход для сотрудников';

  @override
  String get staffLoginLink => 'Войти как сотрудник';

  @override
  String get customerLoginLink => 'Войти как клиент';

  @override
  String get passwordLabel => 'Пароль';

  @override
  String get passwordRequired => 'Введите пароль';

  @override
  String get loginButton => 'Войти';

  @override
  String get changePasswordTitle => 'Смена пароля';

  @override
  String get changePasswordRequiredIntro =>
      'Перед началом работы замените временный пароль на свой';

  @override
  String get currentPasswordLabel => 'Текущий пароль';

  @override
  String get newPasswordLabel => 'Новый пароль';

  @override
  String get confirmPasswordLabel => 'Повторите новый пароль';

  @override
  String get passwordRuleHint => 'От 10 до 128 символов';

  @override
  String get passwordsDoNotMatch => 'Пароли не совпадают';

  @override
  String get savePasswordButton => 'Сохранить';

  @override
  String get passwordChanged => 'Пароль изменён';

  @override
  String get logoutButton => 'Выйти';

  @override
  String get wrongSurfaceMobile =>
      'Эта учётная запись работает в веб-панели. Войдите через браузер на компьютере.';

  @override
  String get wrongSurfaceWeb =>
      'Эта учётная запись работает в мобильном приложении. Войдите через приложение BarakaBozor на телефоне.';

  @override
  String get languageLabel => 'Язык';

  @override
  String get languageUzbek => 'O\'zbekcha';

  @override
  String get languageRussian => 'Русский';

  @override
  String get retryButton => 'Повторить';

  @override
  String get shellCustomer => 'Клиент';

  @override
  String get shellShopper => 'Сборщик';

  @override
  String get shellCourier => 'Курьер';

  @override
  String get shellOperations => 'Операции';

  @override
  String get shellAdmin => 'Администратор';

  @override
  String get shellManager => 'Менеджер';

  @override
  String get shellPlaceholder => 'Этот раздел появится на следующем этапе';

  @override
  String get customerModeLabel => 'Режим клиента';

  @override
  String get staffModeLabel => 'Режим сотрудника';

  @override
  String get switchToCustomer => 'Продолжить как клиент';

  @override
  String get switchToStaff => 'Вернуться в режим сотрудника';

  @override
  String get sessionUnreachableTitle => 'Нет связи с сервером';

  @override
  String get sessionUnreachableBody =>
      'Проверьте подключение к интернету и попробуйте снова';

  @override
  String get errorAuthenticationRequired => 'Войдите заново';

  @override
  String get errorAccountBlocked => 'Эта учётная запись заблокирована';

  @override
  String get errorInvalidCredentials => 'Неверный номер телефона или пароль';

  @override
  String get errorCodeInvalid => 'Неверный код';

  @override
  String get errorCodeExpired => 'Срок действия кода истёк. Запросите новый';

  @override
  String get errorCodeAttemptsExhausted =>
      'Попытки закончились. Запросите новый код';

  @override
  String get errorCodeResendTooSoon =>
      'Подождите немного перед повторной отправкой кода';

  @override
  String get errorRateLimited => 'Слишком много попыток. Подождите немного';

  @override
  String get errorProviderUnavailable =>
      'Сервис временно недоступен. Попробуйте позже';

  @override
  String get errorServiceUnavailable =>
      'Идут технические работы. Попробуйте позже';

  @override
  String get errorServerError => 'Непредвиденная ошибка. Попробуйте позже';

  @override
  String get errorNetwork => 'Нет подключения к интернету';

  @override
  String get errorValidationFailed => 'Проверьте введённые данные';

  @override
  String get errorForbidden => 'Это действие недоступно';

  @override
  String get errorNotFound => 'Не найдено';

  @override
  String get errorPasswordChangeRequired => 'Сначала смените пароль';

  @override
  String get errorUnknown => 'Произошла ошибка. Попробуйте снова';

  @override
  String get adminHomeIntro => 'Выберите раздел';

  @override
  String get adminSectionHome => 'Главная';

  @override
  String get adminSectionSettings => 'Настройки';

  @override
  String get saveButton => 'Сохранить';

  @override
  String get settingsTitle => 'Настройки бизнеса';

  @override
  String get settingsPricingSection => 'Цены и сборы';

  @override
  String get settingsMarkup => 'Наценка, %';

  @override
  String get settingsServiceFeeMode => 'Сервисный сбор';

  @override
  String get settingsServiceFeeFixed => 'Фиксированная сумма';

  @override
  String get settingsServiceFeePercentage => 'Процент от заказа';

  @override
  String get settingsServiceFeeAmount => 'Сумма сервисного сбора';

  @override
  String get settingsServiceFeePercent => 'Сервисный сбор, %';

  @override
  String get settingsDeliveryFee => 'Стоимость доставки';

  @override
  String get settingsMinimumOrder => 'Минимальная сумма заказа';

  @override
  String get settingsPriceTolerance => 'Допустимое превышение цены, %';

  @override
  String get settingsPriceToleranceHint =>
      'Если цена выросла сильнее, спрашиваем согласие клиента';

  @override
  String get settingsOptionalHint => 'Пусто — не задано';

  @override
  String get settingsHoursSection => 'Часы работы';

  @override
  String get settingsOpensAt => 'Открытие';

  @override
  String get settingsClosesAt => 'Закрытие';

  @override
  String get settingsAreaSection => 'Зона доставки';

  @override
  String get settingsCentreLatitude => 'Широта центра';

  @override
  String get settingsCentreLongitude => 'Долгота центра';

  @override
  String get settingsRadius => 'Радиус, км';

  @override
  String get settingsDeliverySection => 'Контроль доставки';

  @override
  String get settingsDelayThreshold => 'Порог опоздания, мин';

  @override
  String get settingsSaved => 'Настройки сохранены';

  @override
  String get settingsNoChanges => 'Изменений нет';

  @override
  String get settingsSaving => 'Сохранение';

  @override
  String get settingsTashkentTimeHint => 'По времени Ташкента';

  @override
  String settingsUpdatedAt(String when) {
    return 'Последнее изменение: $when';
  }

  @override
  String get providersTitle => 'Онлайн-оплата';

  @override
  String get providersIntro =>
      'Включённые системы предлагаются клиенту как способ оплаты';

  @override
  String get fieldRequired => 'Заполните поле';

  @override
  String get fieldPercent =>
      'Число от 0 до 999.99, не более 2 знаков после точки';

  @override
  String get fieldAmount => 'Целое число от 0 до 1 000 000 000';

  @override
  String get fieldTime => 'Время в формате 09:00';

  @override
  String get fieldLatitude => 'От -90 до 90, не более 6 знаков после точки';

  @override
  String get fieldLongitude => 'От -180 до 180, не более 6 знаков после точки';

  @override
  String get fieldRadius =>
      'Больше 0 и не больше 9999.99, не более 2 знаков после точки';

  @override
  String get fieldMinutes => 'Целое число от 1 до 1440';

  @override
  String get fieldPairIncomplete =>
      'Заполните оба значения или оставьте оба пустыми';

  @override
  String get fieldSameTime =>
      'Время закрытия должно отличаться от времени открытия';

  @override
  String get fieldRejected => 'Сервер не принял это значение';
}
