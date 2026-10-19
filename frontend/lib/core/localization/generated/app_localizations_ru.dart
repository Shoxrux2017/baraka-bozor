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
      'Введите номер телефона — пришлём код для входа';

  @override
  String get phoneLabel => 'Номер телефона';

  @override
  String get phoneHint => '90 123 45 67';

  @override
  String get phoneInvalid => 'Введите 9 цифр номера';

  @override
  String get continueButton => 'Продолжить';

  @override
  String get codeSentSms => 'Код отправлен по SMS';

  @override
  String codeSentOnPhone(String phone) {
    return 'Отправили код на $phone';
  }

  @override
  String get codeLabel => 'Код для входа';

  @override
  String get codeInvalidFormat => 'Введите код из 6 цифр';

  @override
  String get verifyButton => 'Подтвердить';

  @override
  String get resendCode => 'Отправить код ещё раз';

  @override
  String resendIn(String time) {
    return 'Отправить ещё раз через $time';
  }

  @override
  String codeLocked(String time) {
    return 'Код введён неверно 3 раза. Новый код можно запросить через $time';
  }

  @override
  String get codeLockOver => 'Запросите новый код';

  @override
  String get changePhone => 'Изменить номер';

  @override
  String codeSentToPhone(String phone) {
    return 'Отправили код в Telegram на $phone';
  }

  @override
  String get cancelButton => 'Отмена';

  @override
  String get wrongSurfaceTitle => 'Откройте веб-панель';

  @override
  String get staffLoginTitle => 'Вход для сотрудников';

  @override
  String get passwordLabel => 'Пароль';

  @override
  String get passwordRequired => 'Введите пароль';

  @override
  String get loginButton => 'Войти';

  @override
  String get changePasswordTitle => 'Придумайте пароль';

  @override
  String get changePasswordRequiredIntro =>
      'Администратор выдал временный пароль. Замените его своим';

  @override
  String get currentPasswordLabel => 'Временный пароль';

  @override
  String get newPasswordLabel => 'Новый пароль';

  @override
  String get confirmPasswordLabel => 'Повторите пароль';

  @override
  String get passwordRuleHint => 'Не меньше 10 символов';

  @override
  String get passwordsDoNotMatch => 'Пароли не совпадают';

  @override
  String get savePasswordButton => 'Сохранить пароль';

  @override
  String get passwordChanged => 'Пароль изменён';

  @override
  String get logoutButton => 'Выйти';

  @override
  String get wrongSurfaceMobile =>
      'Этот аккаунт работает в браузере на компьютере. Войдите через веб-панель BarakaBozor';

  @override
  String get wrongSurfaceWeb =>
      'Этот аккаунт работает в приложении BarakaBozor на телефоне';

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
  String get panelSectionBoard => 'Заказы';

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
  String get errorCodeLocked =>
      'Слишком много неверных попыток. Подождите немного';

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

  @override
  String get adminSectionCategories => 'Категории';

  @override
  String get adminSectionProducts => 'Товары';

  @override
  String get catalogNameUz => 'Название (узбекский)';

  @override
  String get catalogNameRu => 'Название (русский)';

  @override
  String get catalogDescriptionUz => 'Описание (узбекский)';

  @override
  String get catalogDescriptionRu => 'Описание (русский)';

  @override
  String get catalogSortOrder => 'Порядок';

  @override
  String get catalogSortOrderHint => 'Чем меньше, тем выше в списке';

  @override
  String get catalogShownToCustomers => 'Показывать клиентам';

  @override
  String get catalogIncludeArchived => 'Вместе с архивом';

  @override
  String get catalogStateActive => 'Показывается';

  @override
  String get catalogStateHidden => 'Скрыто';

  @override
  String get catalogStateArchived => 'В архиве';

  @override
  String get catalogEdit => 'Изменить';

  @override
  String get catalogArchive => 'В архив';

  @override
  String get catalogRestore => 'Вернуть из архива';

  @override
  String get catalogArchivedNote =>
      'Запись в архиве не видна клиентам. Вернуть её можно действием в списке';

  @override
  String get catalogEmpty => 'Ничего не найдено';

  @override
  String catalogPage(int page, int last) {
    return 'Страница $page из $last';
  }

  @override
  String get catalogPreviousPage => 'Предыдущая страница';

  @override
  String get catalogNextPage => 'Следующая страница';

  @override
  String get categoryNew => 'Новая категория';

  @override
  String get categoryEditTitle => 'Редактирование категории';

  @override
  String get categoryImage => 'Картинка';

  @override
  String get categoryImageAfterSave =>
      'Картинку можно добавить после сохранения';

  @override
  String get categoryRemoveImageConfirm => 'Удалить картинку категории?';

  @override
  String get categorySaved => 'Категория сохранена';

  @override
  String get productNew => 'Новый товар';

  @override
  String get productEditTitle => 'Редактирование товара';

  @override
  String get productSaved => 'Корзина обновлена';

  @override
  String get productCategory => 'Категория';

  @override
  String get productAllCategories => 'Все категории';

  @override
  String get productUnit => 'Единица измерения';

  @override
  String get productFeatured => 'Показывать в «Рекомендуем»';

  @override
  String get productFeaturedHint =>
      'Товар появится в ряду «Рекомендуем» на главной';

  @override
  String get productFeaturedBadge => 'Рекомендуем';

  @override
  String get productMarketPrice => 'Рыночная цена';

  @override
  String productCustomerPrice(String price) {
    return 'Цена для клиента: $price';
  }

  @override
  String get productSearch => 'Поиск по названию';

  @override
  String get productBackToList => 'К списку товаров';

  @override
  String get productImage => 'Фото';

  @override
  String get productNoImage => 'Фото нет';

  @override
  String get productChooseImage => 'Выбрать фото';

  @override
  String get productUploadImage => 'Загрузить';

  @override
  String get productRemoveImage => 'Удалить фото';

  @override
  String get productRemoveImageConfirm => 'Удалить фото товара?';

  @override
  String get productImageRules => 'JPEG, PNG или WebP, не больше 5 МБ';

  @override
  String get productImageTooLarge => 'Фото больше 5 МБ';

  @override
  String get productImageWrongType => 'Только JPEG, PNG или WebP';

  @override
  String get productImageUnreadable =>
      'Не удалось прочитать файл. Выберите другой';

  @override
  String get productImageAfterSave =>
      'Фото можно добавить после сохранения товара';

  @override
  String get priceModeFixed => 'Точная цена';

  @override
  String get priceModeEstimate => 'Ориентировочная цена';

  @override
  String get unitKg => 'кг';

  @override
  String get unitGram => 'г';

  @override
  String get unitPiece => 'шт.';

  @override
  String get unitLiter => 'л';

  @override
  String get unitPackage => 'уп.';

  @override
  String get unitBox => 'кор.';

  @override
  String get unitBundle => 'пуч.';

  @override
  String get unitMeter => 'м';

  @override
  String fieldTooLong(int max) {
    return 'Не более $max символов';
  }

  @override
  String get fieldSortOrder => 'Целое число от -100 000 до 100 000';

  @override
  String get fieldMarketPrice => 'Целое число от 1 до 1 000 000 000';

  @override
  String get errorBusinessConflict =>
      'Данные уже изменились. Проверьте текущее состояние и попробуйте снова';

  @override
  String get errorPayloadTooLarge => 'Файл слишком большой';

  @override
  String get adminSectionStaff => 'Сотрудники';

  @override
  String get legalDocumentsTitle => 'Документы';

  @override
  String get legalTerms => 'Условия использования';

  @override
  String get legalPrivacy => 'Политика конфиденциальности';

  @override
  String get legalFormatHint =>
      '## — заголовок, - — пункт списка, каждая строка — абзац';

  @override
  String legalPublishedBy(String date, String name) {
    return 'Опубликовано $date, $name';
  }

  @override
  String get legalNotPublished => 'Не опубликовано — в приложении строки нет';

  @override
  String get legalPublish => 'Опубликовать';

  @override
  String get legalUnpublishConfirm => 'Снять документ с публикации?';

  @override
  String get legalSaved => 'Документ опубликован';

  @override
  String get customersTitle => 'Покупатели';

  @override
  String get customersPhoneHint => '+998 и 9 цифр';

  @override
  String get customersFind => 'Найти';

  @override
  String get customersNone => 'Покупателей с этим номером нет';

  @override
  String get customerNoName => 'Без имени';

  @override
  String customerOrders(int count) {
    return 'Заказов: $count';
  }

  @override
  String customerUnfinished(String number) {
    return 'Незавершённый заказ № $number';
  }

  @override
  String get customerErase => 'Удалить аккаунт';

  @override
  String get customerEraseBlockedNote =>
      'Аккаунт заблокирован: номер останется в чёрном списке, зарегистрироваться с ним снова будет нельзя.';

  @override
  String get customerEraseTitle => 'Удалить аккаунт покупателя?';

  @override
  String get customerEraseBody =>
      'Сотрём имя, номер, адреса, избранное и корзину. История заказов останется без имени и телефона.';

  @override
  String get customerEraseConfirm => 'Удалить';

  @override
  String get customerErased => 'Аккаунт удалён';

  @override
  String get orderCustomerErased => 'Данные покупателя удалены';

  @override
  String get roleShopper => 'Сборщик';

  @override
  String get roleCourier => 'Курьер';

  @override
  String get roleOperator => 'Оператор';

  @override
  String get roleAdmin => 'Администратор';

  @override
  String get roleManager => 'Менеджер';

  @override
  String get statusActive => 'Активен';

  @override
  String get statusBlocked => 'Заблокирован';

  @override
  String get staffNew => 'Новый сотрудник';

  @override
  String get staffFullName => 'Имя и фамилия';

  @override
  String get staffRole => 'Роль';

  @override
  String get staffAllRoles => 'Все роли';

  @override
  String get staffAllStatuses => 'Все статусы';

  @override
  String get staffNoName => 'Имя не указано';

  @override
  String get staffYou => 'Вы';

  @override
  String get staffEditName => 'Изменить имя';

  @override
  String get staffBlock => 'Заблокировать';

  @override
  String get staffActivate => 'Разблокировать';

  @override
  String get staffResetPassword => 'Сбросить пароль';

  @override
  String staffBlockConfirm(String name) {
    return 'Заблокировать: $name? Все сеансы этого сотрудника сразу завершатся.';
  }

  @override
  String staffResetConfirm(String name) {
    return 'Создать новый временный пароль: $name? Все сеансы этого сотрудника завершатся.';
  }

  @override
  String get staffTemporaryPasswordTitle => 'Временный пароль';

  @override
  String get staffTemporaryPasswordWarning =>
      'Скопируйте пароль сейчас и передайте сотруднику. Больше он показан не будет. При первом входе сотрудник задаст свой пароль.';

  @override
  String get staffCopy => 'Копировать';

  @override
  String get staffCopied => 'Скопировано';

  @override
  String get staffDone => 'Готово';

  @override
  String get staffMustChangePassword => 'Нужна смена пароля';

  @override
  String staffLastLogin(String when) {
    return 'Последний вход: $when';
  }

  @override
  String get staffNeverLoggedIn => 'Входов ещё не было';

  @override
  String get staffSaved => 'Сохранено';

  @override
  String get errorSelfBlockNotAllowed => 'Нельзя заблокировать себя';

  @override
  String get errorLastActiveAdminRequired =>
      'Нельзя заблокировать последнего активного администратора';

  @override
  String get errorSelfResetNotAllowed => 'Свой пароль здесь сбросить нельзя';

  @override
  String get errorPhoneAlreadyActive =>
      'Этот номер уже у другого активного сотрудника';

  @override
  String get catalogSearchHint => 'Найти: огурцы, лепёшки…';

  @override
  String get deliveryAddressEmptyHint => 'Куда привезти заказ';

  @override
  String get homeCategories => 'Категории';

  @override
  String get homeSeeAll => 'Все';

  @override
  String get deliveryAddressAdd => 'Добавить адрес доставки';

  @override
  String get deliveryAddressRetry => 'Адрес не загрузился — повторить';

  @override
  String get deliveryAddressSheetTitle => 'Адрес доставки';

  @override
  String get catalogSearchClear => 'Очистить';

  @override
  String get catalogCategoriesTitle => 'Разделы';

  @override
  String get catalogNoProducts => 'Здесь пока нет товаров';

  @override
  String catalogPricePerUnit(String price, String unit) {
    return '$price / $unit';
  }

  @override
  String get catalogEstimateExplain =>
      'Итоговая цена рассчитывается от цены, которую сборщик фактически заплатит на рынке. Если она превысит ориентировочную больше допустимого, мы спросим вашего согласия до покупки.';

  @override
  String get catalogLoadMore => 'Загрузить ещё';

  @override
  String get homeNavHome => 'Главная';

  @override
  String get homeNavOrders => 'Заказы';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileName => 'Ваше имя';

  @override
  String get profileNameNeeded => 'Чтобы оформить заказ, укажите имя';

  @override
  String get profileSaved => 'Имя сохранено';

  @override
  String get addressesTitle => 'Мои адреса';

  @override
  String get addressNone => 'Адресов пока нет';

  @override
  String get addressNew => 'Новый адрес';

  @override
  String get addressEdit => 'Изменить адрес';

  @override
  String get addressStreet => 'Улица';

  @override
  String get addressHouse => 'Дом';

  @override
  String get addressApartment => 'Квартира';

  @override
  String get addressLandmark => 'Ориентир';

  @override
  String get addressDeliveryNote => 'Комментарий для курьера';

  @override
  String get addressFieldStreet => 'Улица, массив или квартал';

  @override
  String get addressFieldApartment => 'Квартира или офис';

  @override
  String get addressLandmarkHint => 'Например: напротив школы № 64';

  @override
  String get addressFieldNote => 'Комментарий курьеру';

  @override
  String get addressNoteHint => 'Подъезд, этаж, код домофона';

  @override
  String get addressLabelTitle => 'Как назвать адрес';

  @override
  String get addressLabelHome => 'Дом';

  @override
  String get addressLabelWork => 'Работа';

  @override
  String get addressLabelCustom => 'Своё';

  @override
  String get addressLabelName => 'Название';

  @override
  String get addressChangePoint => 'Изменить точку';

  @override
  String get addressSaveButton => 'Сохранить адрес';

  @override
  String get addressMapHint =>
      'Передвиньте карту, чтобы метка встала на вход в ваш дом';

  @override
  String get addressPointTitle => 'Точка доставки';

  @override
  String get addressSearchHint => 'Или напишите адрес: улица, дом';

  @override
  String get addressSearchFound =>
      'Проверьте метку: курьер приедет точно к ней';

  @override
  String get addressPointText =>
      'Курьер приедет к метке. Квартиру, подъезд и ориентир укажете на следующем шаге.';

  @override
  String get addressSearchNotFound =>
      'На карте такого адреса не нашлось. Передвиньте карту и поставьте метку на свой дом сами.';

  @override
  String get addressSearchUnavailable =>
      'Поиск адреса сейчас не работает. Передвиньте карту и поставьте метку сами.';

  @override
  String get addressWordsKept => 'Ваш адрес словами сохраним для курьера';

  @override
  String get addressMyLocation => 'Где я';

  @override
  String get addressLocationFailed =>
      'Не удалось определить, где вы. Передвиньте карту сами.';

  @override
  String get addressSearchClear => 'Очистить';

  @override
  String get addressPointConfirm => 'Подтвердить точку';

  @override
  String get addressMapUnavailable =>
      'В этой сборке нет карты. Введите координаты точки';

  @override
  String get addressLatitude => 'Широта';

  @override
  String get addressLongitude => 'Долгота';

  @override
  String get addressLatitudeInvalid => 'Широта должна быть числом от -90 до 90';

  @override
  String get addressLongitudeInvalid =>
      'Долгота должна быть числом от -180 до 180';

  @override
  String get addressOutsideAreaPlain => 'Этот адрес вне зоны доставки';

  @override
  String get noChanges => 'Изменений нет';

  @override
  String addressOutsideArea(String distance, String max) {
    return 'Адрес вне зоны доставки: $distance км. Мы доставляем в радиусе $max км';
  }

  @override
  String get addressSaved => 'Адрес сохранён';

  @override
  String get addressAddNew => 'Добавить новый адрес';

  @override
  String get addressMenuEdit => 'Изменить';

  @override
  String addressLandmarkLine(String landmark) {
    return 'Ориентир: $landmark';
  }

  @override
  String addressApartmentShort(String apartment) {
    return 'кв. $apartment';
  }

  @override
  String get addressRemove => 'Удалить';

  @override
  String get addressRemoveConfirm => 'Удалить этот адрес?';

  @override
  String get errorConfigurationIncomplete =>
      'Сервис ещё не настроен до конца. Попробуйте позже';

  @override
  String get orderStatusNew => 'Новый';

  @override
  String get orderStatusShoppingAssigned => 'Назначен сборщик';

  @override
  String get orderStatusShopping => 'Собирается';

  @override
  String get orderStatusFinalPaymentPending => 'Ожидает оплаты';

  @override
  String get orderStatusReadyForDelivery => 'Готов к доставке';

  @override
  String get orderStatusDeliveryAssigned => 'Назначен курьер';

  @override
  String get orderStatusOnTheWay => 'В пути';

  @override
  String get orderStatusCompleted => 'Выполнен';

  @override
  String get orderStatusCancelled => 'Отменён';

  @override
  String get paymentCash => 'Наличные';

  @override
  String get paymentOnline => 'Онлайн';

  @override
  String get totalKindEstimate => 'ориентировочно';

  @override
  String get totalKindFinal => 'окончательно';

  @override
  String get totalNothingDue => 'К оплате нет';

  @override
  String get itemStatusPending => 'Ожидает';

  @override
  String get itemStatusAwaitingCustomer => 'Ждёт ответа клиента';

  @override
  String get itemStatusPurchased => 'Куплено';

  @override
  String get itemStatusRemoved => 'Удалено';

  @override
  String get substitutionAllowSimilar => 'Можно заменить похожим';

  @override
  String get substitutionContactBefore => 'Связаться перед заменой';

  @override
  String get substitutionRemoveIfUnavailable => 'Если нет — убрать';

  @override
  String get removedUnavailable => 'товара не было';

  @override
  String get removedCustomerRejected => 'клиент отказался';

  @override
  String get removedApprovalExpired => 'истёк срок ответа';

  @override
  String get removedCustomerRemoved => 'удалил клиент';

  @override
  String get removedOperatorRemoved => 'удалил оператор';

  @override
  String get removedOrderCancelled => 'заказ отменён';

  @override
  String get cancelCustomerCancelled => 'Отменён клиентом';

  @override
  String get cancelRequestApproved => 'Одобрен запрос на отмену';

  @override
  String get cancelUnpaidOnline => 'Не оплачен онлайн';

  @override
  String get cancelNoItemsPurchased => 'Ничего не куплено';

  @override
  String get cancelDeliveryFailed => 'Доставка не удалась';

  @override
  String get cancelSystem => 'Отменён системой';

  @override
  String get boardRefresh => 'Обновить';

  @override
  String get boardSearch => 'Номер, телефон или имя';

  @override
  String get boardAllStatuses => 'Все статусы';

  @override
  String get boardAllPaymentMethods => 'Все способы оплаты';

  @override
  String get boardAllShoppers => 'Все сборщики';

  @override
  String get boardDays => 'Даты';

  @override
  String get boardClearDays => 'Сбросить даты';

  @override
  String get boardSelfOrdersOnly => 'Только заказы для себя';

  @override
  String get boardClearFilters => 'Сбросить фильтры';

  @override
  String get boardEmpty => 'Заказов пока нет';

  @override
  String get boardEmptyFiltered => 'Нет заказов по этим фильтрам';

  @override
  String get boardColumnNumber => 'Номер';

  @override
  String get boardColumnPlaced => 'Время';

  @override
  String get boardColumnCustomer => 'Клиент';

  @override
  String get boardColumnStatus => 'Статус';

  @override
  String get boardColumnPayment => 'Оплата';

  @override
  String get boardColumnTotal => 'Сумма';

  @override
  String boardItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count позиции',
      many: '$count позиций',
      few: '$count позиции',
      one: '$count позиция',
    );
    return '$_temp0';
  }

  @override
  String get boardNoShopper => 'Не назначен';

  @override
  String boardOrderNumber(String number) {
    return '№$number';
  }

  @override
  String get selfOrderMark => 'Для себя';

  @override
  String get selfOrderExplained => 'Сборщик — сам заказчик';

  @override
  String get summaryCompletedToday => 'Выполнено сегодня';

  @override
  String get summaryCancelledToday => 'Отменено сегодня';

  @override
  String get summarySalesToday => 'Продажи сегодня';

  @override
  String get summaryAttention => 'Требуют внимания';

  @override
  String get attentionTitle => 'Требует внимания';

  @override
  String get attentionEmpty => 'Пока ничего нет';

  @override
  String get attentionApprovalPending =>
      'Клиент не отвечает 10 минут — позвоните';

  @override
  String get attentionApprovalExpired =>
      'Время ответа клиента истекло — уберите товар';

  @override
  String get attentionPaymentOverdue => 'Онлайн-оплата просрочена';

  @override
  String get attentionRefundOutstanding => 'Ожидается возврат денег';

  @override
  String get attentionCourierDelayed => 'Курьер опаздывает';

  @override
  String get attentionDeliveryFailed =>
      'Доставка не удалась — назначьте курьера или отмените';

  @override
  String get attentionCancellationRequest => 'Клиент просит отменить заказ';

  @override
  String get attentionStaffBlocked =>
      'Исполнитель заблокирован — назначьте другого';

  @override
  String get attentionOther => 'Требует внимания';

  @override
  String attentionSince(String time) {
    return 'с $time';
  }

  @override
  String orderTitle(String number) {
    return 'Заказ №$number';
  }

  @override
  String get orderBackToBoard => 'К заказам';

  @override
  String orderPlacedAt(String time) {
    return 'Создан: $time';
  }

  @override
  String orderCompletedAt(String time) {
    return 'Выполнен: $time';
  }

  @override
  String orderCancelledAt(String time) {
    return 'Отменён: $time';
  }

  @override
  String get orderSectionCustomer => 'Клиент';

  @override
  String get orderSectionAddress => 'Адрес';

  @override
  String get orderSectionDeliveryWish => 'Пожелание по времени доставки';

  @override
  String get orderSectionItems => 'Позиции';

  @override
  String get orderSectionTotals => 'Расчёт';

  @override
  String get orderSectionShoppers => 'Сборщики';

  @override
  String get orderSectionHistory => 'История';

  @override
  String get orderNoDeliveryWish => 'Пожеланий нет';

  @override
  String orderCoordinates(String latitude, String longitude) {
    return 'Координаты: $latitude, $longitude';
  }

  @override
  String itemMarketPrice(String price) {
    return 'Рыночная цена: $price';
  }

  @override
  String itemCustomerPrice(String price) {
    return 'Цена для клиента: $price';
  }

  @override
  String itemMarkup(String percent) {
    return 'Наценка: $percent%';
  }

  @override
  String itemLineTotal(String amount) {
    return 'Сумма: $amount';
  }

  @override
  String itemNote(String note) {
    return 'Комментарий: $note';
  }

  @override
  String itemRemovedBecause(String reason) {
    return 'Удалено: $reason';
  }

  @override
  String get totalsMerchandise => 'Товары';

  @override
  String get totalsServiceFee => 'Сервисный сбор';

  @override
  String get totalsDeliveryFee => 'Доставка';

  @override
  String get totalsTotal => 'Итого';

  @override
  String get assignmentCurrent => 'Текущий';

  @override
  String assignmentAssignedBy(String name, String time) {
    return 'Назначил $name, $time';
  }

  @override
  String assignmentAccepted(String time) {
    return 'Принял: $time';
  }

  @override
  String assignmentStarted(String time) {
    return 'Начал сборку: $time';
  }

  @override
  String assignmentEnded(String time, String reason) {
    return 'Завершено: $time, $reason';
  }

  @override
  String get assignmentEndCompleted => 'сборка завершена';

  @override
  String get assignmentEndReassigned => 'передан другому сборщику';

  @override
  String get assignmentEndOrderCancelled => 'заказ отменён';

  @override
  String get assignmentsNone => 'Сборщик ещё не назначен';

  @override
  String get personWithoutName => 'Без имени';

  @override
  String get historyNone => 'История пока пуста';

  @override
  String get historySystem => 'Система';

  @override
  String get historyPaymentProvider => 'Платёжная система';

  @override
  String get historyEventStatusChanged => 'Статус изменён';

  @override
  String get historyEventEdited => 'Заказ изменён';

  @override
  String get historyEventPaymentMethodSwitched => 'Способ оплаты изменён';

  @override
  String get historyEventPriceCorrected => 'Цена исправлена';

  @override
  String get historyEventShopperAssigned => 'Назначен сборщик';

  @override
  String get historyEventShopperReassigned => 'Сборщик заменён';

  @override
  String get historyEventCourierAssigned => 'Назначен курьер';

  @override
  String get historyEventCourierReassigned => 'Курьер заменён';

  @override
  String get historyEventDeliveryFailed => 'Доставка не удалась';

  @override
  String get historyEventApprovalRequested => 'Запрошено согласие клиента';

  @override
  String get historyEventApprovalDecided => 'Клиент ответил';

  @override
  String get historyEventApprovalExpired => 'Срок ответа истёк';

  @override
  String get historyEventApprovalResolved => 'Согласование закрыто';

  @override
  String get historyEventShopperAccepted => 'Сборщик принял заказ';

  @override
  String get historyEventCourierAccepted => 'Курьер принял заказ';

  @override
  String get historyEventItemPurchased => 'Товар куплен';

  @override
  String get historyEventItemUnavailable => 'Товара нет в наличии';

  @override
  String get historyEventItemSubstituted => 'Товар заменён';

  @override
  String get historyEventCancellationRequested =>
      'Клиент попросил отменить заказ';

  @override
  String get historyEventCancellationRequestDecided =>
      'Запрос на отмену рассмотрен';

  @override
  String get historyEventPaymentRecorded => 'Оплата получена';

  @override
  String get historyDeliveryWishChanged => 'изменено пожелание по доставке';

  @override
  String historyAssignedTo(String name) {
    return 'Сборщик: $name';
  }

  @override
  String historyEditAdded(int count) {
    return 'добавлено: $count';
  }

  @override
  String historyEditRemoved(int count) {
    return 'удалено: $count';
  }

  @override
  String historyEditChanged(int count) {
    return 'изменено: $count';
  }

  @override
  String historyReassignedTo(String previous, String name) {
    return 'Сборщик: $previous → $name';
  }

  @override
  String get boardFilteredShopper => 'Выбранный сборщик';

  @override
  String get boardFilterStatus => 'Статус';

  @override
  String get boardFilterPayment => 'Способ оплаты';

  @override
  String get boardFilterShopper => 'Сборщик';

  @override
  String get errorOrderStateConflict =>
      'Заказ уже изменился, мы его обновили. Проверьте и попробуйте снова';

  @override
  String get errorStaffNotActive =>
      'Этот сотрудник заблокирован. Выберите другого';

  @override
  String get assignShopper => 'Назначить сборщика';

  @override
  String get reassignShopper => 'Сменить сборщика';

  @override
  String get pickShopperTitle => 'Выберите сборщика';

  @override
  String get pickShopperEmpty => 'Нет активных сборщиков';

  @override
  String shopperOrdersNow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count заказа',
      many: '$count заказов',
      few: '$count заказа',
      one: '$count заказ',
    );
    return 'Сейчас $_temp0';
  }

  @override
  String get assigningShopper => 'Назначаем сборщика';

  @override
  String get cartTitle => 'Корзина';

  @override
  String get cartOpen => 'Открыть корзину';

  @override
  String cartBadge(int count) {
    return 'Корзина: $count';
  }

  @override
  String get cartAdded => 'Добавлено в корзину';

  @override
  String get cartQuantity => 'Количество';

  @override
  String get cartQuantityFraction =>
      'Число больше 0: до 4 цифр и до 3 знаков после запятой';

  @override
  String get cartQuantityWhole => 'Целое число от 1 до 9999';

  @override
  String get cartDecrease => 'Уменьшить';

  @override
  String get cartIncrease => 'Увеличить';

  @override
  String get cartNote => 'Комментарий для сборщика';

  @override
  String get cartSubstitution => 'Если товара нет';

  @override
  String cartLineEstimate(String amount) {
    return '≈ $amount';
  }

  @override
  String get cartLineUnavailable => 'Сейчас нет в продаже';

  @override
  String get cartUnavailableHint =>
      'Уберите товары, которых нет в продаже, — с ними заказ не оформить';

  @override
  String get cartSaving => 'Сохраняем';

  @override
  String get errorCartItemAlreadyExists => 'Этот товар уже в корзине';

  @override
  String get errorCartFull => 'В корзине может быть не больше 100 позиций';

  @override
  String get errorProductUnavailable => 'Этого товара сейчас нет в продаже';

  @override
  String get checkoutTitle => 'Оформление';

  @override
  String get checkoutGo => 'Оформить';

  @override
  String get checkoutPayment => 'Способ оплаты';

  @override
  String get checkoutOnlineUnavailable =>
      'Пока можно оплатить только наличными';

  @override
  String get checkoutCalculating => 'Рассчитываем';

  @override
  String get checkoutPlacing => 'Отправляем заказ';

  @override
  String checkoutPlaced(String number) {
    return 'Заказ № $number оформлен';
  }

  @override
  String get checkoutOpenProfile => 'Указать имя';

  @override
  String get checkoutBackToCart => 'Вернуться в корзину';

  @override
  String get errorProfileIncomplete =>
      'Чтобы оформить заказ, укажите имя в профиле';

  @override
  String get errorAddressIncomplete => 'Адрес неполный: укажите улицу и дом';

  @override
  String get errorAddressGone => 'Этот адрес не найден. Выберите другой';

  @override
  String get errorCartEmpty => 'Корзина пуста';

  @override
  String get errorCheckoutProductsUnavailable =>
      'Некоторые товары сейчас нельзя заказать: уберите их из корзины или исправьте количество';

  @override
  String errorMinimumOrder(String minimum, String shortfall) {
    return 'Минимальный заказ — $minimum. Добавьте товаров ещё на $shortfall';
  }

  @override
  String get errorMinimumOrderPlain => 'Сумма заказа ниже минимальной';

  @override
  String get errorPaymentMethodUnavailable =>
      'Этот способ оплаты сейчас недоступен';

  @override
  String get errorCheckoutStale =>
      'Расчёт устарел и обновлён. Проверьте и подтвердите снова';

  @override
  String get errorOrderInProgress =>
      'Заказ ещё отправляется. Подождите и подтвердите снова';

  @override
  String get checkoutUnconfirmed =>
      'Не удалось узнать, принят ли заказ. Нажмите «Заказать» ещё раз — дважды он не оформится';

  @override
  String get cartUnconfirmedOrder =>
      'Не удалось узнать, принят ли ваш последний заказ';

  @override
  String get cartCheckUnconfirmed => 'Проверить';

  @override
  String get errorInProgress =>
      'Запрос ещё выполняется. Подождите и попробуйте снова';

  @override
  String checkoutPlacedCancelled(String number) {
    return 'Заказ №$number отменён';
  }

  @override
  String get checkoutWhere => 'Куда привезти';

  @override
  String get checkoutWishLabel => 'Пожелание к доставке';

  @override
  String get checkoutWishHint => 'Например: после 18:00, позвонить заранее';

  @override
  String get paymentCashTitle => 'Наличными курьеру';

  @override
  String get paymentCashHint =>
      'При получении, точную сумму покажем после сборки';

  @override
  String get paymentOnlineTitle => 'Онлайн: Payme или Click';

  @override
  String get checkoutSoon => 'Скоро';

  @override
  String checkoutItems(int count) {
    return 'Товары · $count';
  }

  @override
  String get checkoutOrder => 'Заказать';

  @override
  String checkoutClosedBanner(String time) {
    return 'Сейчас мы закрыты. Заказ примем сейчас, а соберём и привезём после открытия — в $time.';
  }

  @override
  String get checkoutRecounted =>
      'Пока вы оформляли, заказ пересчитали. Проверьте итог и нажмите «Заказать» ещё раз.';

  @override
  String checkoutGoneTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Товары закончились',
      many: 'Товары закончились',
      few: 'Товары закончились',
      one: 'Товар закончился',
    );
    return '$_temp0';
  }

  @override
  String checkoutGoneText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Пока вы оформляли, на рынке закончились товары:',
      many: 'Пока вы оформляли, на рынке закончились товары:',
      few: 'Пока вы оформляли, на рынке закончились товары:',
      one: 'Пока вы оформляли, на рынке закончился товар:',
    );
    return '$_temp0';
  }

  @override
  String checkoutGoneHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Уберите их в корзине — остальное оформим как обычно.',
      many: 'Уберите их в корзине — остальное оформим как обычно.',
      few: 'Уберите их в корзине — остальное оформим как обычно.',
      one: 'Уберите его в корзине — остальное оформим как обычно.',
    );
    return '$_temp0';
  }

  @override
  String get checkoutGoneAction => 'В корзину';

  @override
  String get checkoutPlacedCash =>
      'Сборщик купит всё на рынке. Точную сумму покажем в заказе после сборки — её вы отдадите курьеру наличными.';

  @override
  String checkoutPlacedCashFinal(String amount) {
    return 'Сборщик купит всё на рынке. К оплате курьеру наличными: $amount.';
  }

  @override
  String checkoutPlacedOpensAt(String time) {
    return 'Начнём собирать после открытия — в $time.';
  }

  @override
  String get checkoutOrderStatus => 'Статус заказа';

  @override
  String get checkoutToHome => 'На главную';

  @override
  String get myOrders => 'Мои заказы';

  @override
  String get myOrdersEmpty => 'Заказов пока нет';

  @override
  String get customerStatusNew => 'Принят';

  @override
  String get customerStatusShoppingAssigned => 'Назначен сборщик';

  @override
  String get customerStatusShopping => 'Собирается';

  @override
  String get customerStatusFinalPaymentPending => 'Ждёт оплаты';

  @override
  String get customerStatusReadyForDelivery => 'Готов к доставке';

  @override
  String get customerStatusDeliveryAssigned => 'Назначен курьер';

  @override
  String get customerStatusOnTheWay => 'В пути';

  @override
  String get customerStatusCompleted => 'Доставлен';

  @override
  String get customerStatusCancelled => 'Отменён';

  @override
  String get orderEdit => 'Изменить';

  @override
  String orderEditKitTitle(int number) {
    return 'Изменить заказ № $number';
  }

  @override
  String get orderEditInfo =>
      'Менять можно, пока сборщик не начал покупать. У товаров, что уже в заказе, цена остаётся прежней.';

  @override
  String get orderEditNew => 'Новый';

  @override
  String get orderEditRecount =>
      'Доставку, сбор и итог пересчитаем после сохранения';

  @override
  String get orderPickInOrder => 'В заказе';

  @override
  String get orderEditRemoveLine => 'Убрать из заказа';

  @override
  String get orderEditKeepLine => 'Вернуть';

  @override
  String get orderEditAtLeastOne =>
      'В заказе должен остаться хотя бы один товар';

  @override
  String get orderEditSaving => 'Сохраняем';

  @override
  String get orderEditClosed => 'Этот заказ уже нельзя изменить';

  @override
  String get orderAddProduct => 'Добавить товар';

  @override
  String get orderAddTitle => 'Добавить в заказ';

  @override
  String get orderAddAlreadyIn =>
      'Этот товар уже в заказе — его можно изменить';

  @override
  String orderAddFull(int count) {
    return 'В заказе может быть не больше $count товаров';
  }

  @override
  String get orderCancelReason => 'Причина (необязательно)';

  @override
  String get orderCancelRepeating =>
      'Прошлый запрос остался без ответа: он повторится с той же причиной';

  @override
  String get orderCancelling => 'Отменяем';

  @override
  String get orderCancellationNeedsReason =>
      'Заказ уже в работе: напишите причину отмены, и решит оператор';

  @override
  String get orderOpen => 'Открыть заказ';

  @override
  String get errorOrderEditingLocked =>
      'Заказ уже нельзя изменить. Заказ обновлён';

  @override
  String get errorOrderCancellationNotAllowed =>
      'Заказ уже нельзя отменить. Заказ обновлён';

  @override
  String get boardColumnPeople => 'Сборщик и курьер';

  @override
  String boardCourierNamed(String name) {
    return 'Курьер: $name';
  }

  @override
  String get boardFilterCourier => 'Курьер';

  @override
  String get boardAllCouriers => 'Все курьеры';

  @override
  String get boardFilteredCourier => 'Выбранный курьер';

  @override
  String get boardAwaitingCustomerOnly => 'Ждут ответа клиента';

  @override
  String boardPendingQuestions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вопроса клиенту',
      many: '$count вопросов клиенту',
      few: '$count вопроса клиенту',
      one: '$count вопрос клиенту',
    );
    return '$_temp0';
  }

  @override
  String attentionShowAll(int count) {
    return 'Показать все ($count)';
  }

  @override
  String get attentionShowFewer => 'Свернуть';

  @override
  String get orderSectionCouriers => 'Курьеры';

  @override
  String get assignCourier => 'Назначить курьера';

  @override
  String get reassignCourier => 'Сменить курьера';

  @override
  String get assigningCourier => 'Назначаем курьера';

  @override
  String get pickCourierTitle => 'Выберите курьера';

  @override
  String get pickCourierEmpty => 'Нет активных курьеров';

  @override
  String courierStarted(String time) {
    return 'Выехал: $time';
  }

  @override
  String get courierEndCompleted => 'доставлено';

  @override
  String get courierEndReassigned => 'передан другому курьеру';

  @override
  String get courierEndDeliveryFailed => 'не доставлено';

  @override
  String get deliveryFailureNoAnswer => 'Клиент не ответил';

  @override
  String get deliveryFailureRefused => 'Клиент отказался';

  @override
  String get deliveryFailureWrongAddress => 'Неверный адрес';

  @override
  String get deliveryFailureOther => 'Другая причина';

  @override
  String staffBlockCurrentOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сейчас у сотрудника $count заказа',
      many: 'Сейчас у сотрудника $count заказов',
      few: 'Сейчас у сотрудника $count заказа',
      one: 'Сейчас у сотрудника $count заказ',
    );
    return '$_temp0. Начатая сборка или доставка в пути не перейдёт к другому.';
  }

  @override
  String get courierAssignmentsNone => 'Курьер ещё не назначен';

  @override
  String historyCourierAssignedTo(String name) {
    return 'Курьер: $name';
  }

  @override
  String historyCourierReassignedTo(String previous, String name) {
    return 'Курьер: $previous → $name';
  }

  @override
  String get staffBlockOrdersLoading =>
      'Загружаем, сколько заказов у сотрудника…';

  @override
  String get staffBlockOrdersUnknown =>
      'Не удалось узнать, сколько заказов у сотрудника. Начатая сборка или доставка в пути не перейдёт к другому.';

  @override
  String get orderSectionApprovals => 'Вопросы клиенту';

  @override
  String get orderSectionCancellationRequests => 'Запросы на отмену';

  @override
  String get orderSectionPayment => 'Оплата';

  @override
  String itemBought(String quantity) {
    return 'Куплено: $quantity';
  }

  @override
  String itemBilled(String quantity) {
    return 'К оплате: $quantity';
  }

  @override
  String itemPricePaid(String price) {
    return 'Цена покупки: $price';
  }

  @override
  String itemBilledPrice(String price) {
    return 'Цена к оплате: $price';
  }

  @override
  String itemReplacedWith(String name) {
    return 'Замена: $name';
  }

  @override
  String get replacementAutomatic => 'автоматически';

  @override
  String get replacementApproved => 'с согласия клиента';

  @override
  String get approvalsNone => 'Вопросов клиенту не было';

  @override
  String get approvalTypePrice => 'Цена выше допустимой';

  @override
  String get approvalTypeSubstitution => 'Замена';

  @override
  String get approvalTypeReducedQuantity => 'Меньшее количество';

  @override
  String get approvalStatusPending => 'Ждёт ответа';

  @override
  String get approvalStatusApproved => 'Клиент согласился';

  @override
  String get approvalStatusRejected => 'Клиент отказался';

  @override
  String get approvalStatusExpired => 'Срок истёк';

  @override
  String get approvalStatusCancelled => 'Закрыт';

  @override
  String approvalProposedPrice(String price, String paid) {
    return 'Предложено: $price, цена покупки $paid';
  }

  @override
  String approvalProposedQuantity(String quantity) {
    return 'Предложено: $quantity';
  }

  @override
  String approvalReplacement(String name) {
    return 'Замена: $name';
  }

  @override
  String approvalAskedBy(String name, String time) {
    return 'Спросил(а) $name, $time';
  }

  @override
  String approvalTimers(String attention, String expires) {
    return 'Внимание с $attention · Срок до $expires';
  }

  @override
  String approvalResolvedBy(String name, String time) {
    return 'Решение: $name, $time';
  }

  @override
  String approvalClosedAt(String time) {
    return 'Закрыт: $time';
  }

  @override
  String get approvalLineRemoved => 'Товар убран из заказа';

  @override
  String get removeExpiredLine => 'Убрать товар';

  @override
  String removeExpiredTitle(String name) {
    return 'Убрать «$name»?';
  }

  @override
  String get removeExpiredExplained =>
      'Клиент не ответил вовремя. Товар будет убран из заказа; если покупать больше нечего, заказ отменится.';

  @override
  String get cancellationRequestsNone => 'Запросов на отмену не было';

  @override
  String get requestStatusPending => 'Ждёт решения';

  @override
  String get requestStatusApproved => 'Одобрен';

  @override
  String get requestStatusRejected => 'Отклонён';

  @override
  String get requestStatusClosed => 'Закрыт';

  @override
  String get requestOriginCustomer => 'От клиента';

  @override
  String get requestOriginStaff => 'От сотрудника';

  @override
  String requestReason(String reason) {
    return 'Причина: $reason';
  }

  @override
  String requestFiledBy(String name, String time) {
    return '$name, $time';
  }

  @override
  String requestDecidedBy(String name, String time) {
    return 'Решение: $name, $time';
  }

  @override
  String requestClosedAt(String time) {
    return 'Закрыт: $time';
  }

  @override
  String get approveRequest => 'Одобрить отмену';

  @override
  String get rejectRequest => 'Отклонить';

  @override
  String get approveRequestTitle => 'Отменить заказ?';

  @override
  String get approveRequestExplained =>
      'Заказ будет отменён: текущее назначение завершится, открытые товары уберутся, купленное останется купленным, к оплате ничего не будет.';

  @override
  String get rejectRequestTitle => 'Отклонить запрос?';

  @override
  String get rejectRequestExplained => 'Заказ продолжится.';

  @override
  String get cancelFailedDelivery => 'Отменить заказ';

  @override
  String get cancelFailedDeliveryTitle => 'Отменить заказ?';

  @override
  String get cancelFailedDeliveryExplained =>
      'Заказ будет отменён с причиной «доставка не удалась».';

  @override
  String get actionNote => 'Комментарий (необязательно)';

  @override
  String get paymentNone => 'Оплата ещё не записана';

  @override
  String get paymentStatusUnpaid => 'Не оплачено';

  @override
  String get paymentStatusPending => 'Ожидает';

  @override
  String get paymentStatusPaid => 'Оплачено';

  @override
  String get paymentStatusCancelled => 'Отменено';

  @override
  String paymentAmount(String amount) {
    return 'Сумма: $amount';
  }

  @override
  String paymentPaidAt(String time) {
    return 'Время оплаты: $time';
  }

  @override
  String paymentRecordedBy(String name) {
    return 'Принял(а): $name';
  }

  @override
  String get correctPrice => 'Исправить цену';

  @override
  String correctPriceTitle(String name) {
    return 'Исправление цены: $name';
  }

  @override
  String get correctPriceNew => 'Новая цена покупки, сум';

  @override
  String get correctPriceReason => 'Причина';

  @override
  String errorPriceAboveCeiling(String ceiling) {
    return 'Цена для клиента выйдет за предел. Введите цену покупки, при которой клиент платит не больше $ceiling.';
  }

  @override
  String get errorPriceAboveCeilingPlain =>
      'Цена для клиента выйдет за предел.';

  @override
  String historyPriceCorrectedDetails(
    String name,
    String oldPaid,
    String newPaid,
    String oldBilled,
    String newBilled,
  ) {
    return '$name: цена покупки $oldPaid → $newPaid, для клиента $oldBilled → $newBilled';
  }

  @override
  String get errorApprovalNotExpired => 'Срок вопроса ещё не истёк.';

  @override
  String get errorApprovalAlreadyResolved => 'Вопрос уже решён.';

  @override
  String get errorRequestAlreadyDecided => 'По запросу уже принято решение.';

  @override
  String get errorCancellationAlreadyPending =>
      'Есть запрос на отмену — сначала примите по нему решение.';

  @override
  String get errorPriceCorrectionLocked =>
      'Цену уже нельзя исправить: заказ в пути, завершён, отменён или оплачивается онлайн.';

  @override
  String get errorPriceCorrectionNotApplicable =>
      'Цену этой позиции исправить нельзя.';

  @override
  String get staffMenu => 'Меню';

  @override
  String get shopperOrdersEmpty =>
      'Пока вам не назначено заказов. Назначенный заказ появится здесь.';

  @override
  String shopperOpenLines(int open, int total) {
    return 'Осталось позиций: $open из $total';
  }

  @override
  String get shopperNotAccepted => 'Новый заказ — примите его';

  @override
  String shopperAssignedAt(String time) {
    return 'Назначен: $time';
  }

  @override
  String shopperAcceptedAt(String time) {
    return 'Принят: $time';
  }

  @override
  String shopperStartedAt(String time) {
    return 'Сборка начата: $time';
  }

  @override
  String get shopperAccept => 'Принять';

  @override
  String get shopperStart => 'Начать сборку';

  @override
  String callCustomer(String phone) {
    return 'Позвонить клиенту: $phone';
  }

  @override
  String callFailed(String phone) {
    return 'Не удалось открыть приложение для звонков. Наберите номер вручную: $phone';
  }

  @override
  String shopperLineCap(String quantity) {
    return 'Согласовано с клиентом: $quantity';
  }

  @override
  String shopperPriceLimit(String price) {
    return 'Без вопроса клиенту не дороже: $price';
  }

  @override
  String shopperQuestion(String type, String time) {
    return 'Ждём ответа клиента ($type) до $time';
  }

  @override
  String get shopperPageEmpty =>
      'На этой странице заказов не осталось. Перейдите на предыдущую.';

  @override
  String get lineBuy => 'Купить';

  @override
  String get lineReplace => 'Заменить';

  @override
  String get lineUnavailable => 'Нет в наличии';

  @override
  String purchaseTitle(String name) {
    return 'Покупка: $name';
  }

  @override
  String get purchaseQuantity => 'Сколько куплено';

  @override
  String get purchasePrice => 'Цена за единицу (оплачено)';

  @override
  String get purchasePriceOptional =>
      'Товар с фиксированной ценой: цену можно не вводить';

  @override
  String get purchaseSave => 'Записать покупку';

  @override
  String get purchaseAgain => 'Отправить снова';

  @override
  String get purchaseUnconfirmed =>
      'На последнюю покупку нет ответа — та же покупка будет отправлена снова.';

  @override
  String get purchaseAboveBound =>
      'Эта цена выше той, что можно платить без вопроса клиенту. Спросить клиента?';

  @override
  String purchaseBelowQuantity(String quantity) {
    return 'Клиенту нужно $quantity. Купите столько или спросите клиента, согласен ли он на меньшее.';
  }

  @override
  String get askNote => 'Комментарий для клиента (необязательно)';

  @override
  String get askPrice => 'Спросить клиента о цене';

  @override
  String get askQuantity => 'Спросить клиента о количестве';

  @override
  String get typoTitle => 'Проверьте цену';

  @override
  String typoExplained(String price, String market) {
    return 'Вы ввели $price, а рыночная цена $market. Всё верно?';
  }

  @override
  String get typoConfirm => 'Да, верно';

  @override
  String get typoCancel => 'Исправлю';

  @override
  String unavailableTitle(String name) {
    return '«$name» нет в наличии?';
  }

  @override
  String get unavailableExplained =>
      'Товар будет убран из заказа. Если покупать больше нечего, заказ отменится.';

  @override
  String get unavailableConfirm => 'Да, нет в наличии';

  @override
  String replaceTitle(String name) {
    return 'Замена для «$name»';
  }

  @override
  String get replaceSearchHint => 'Название товара';

  @override
  String get replaceNone => 'Подходящих товаров нет';

  @override
  String substituteTitle(String name) {
    return 'Взять вместо: $name';
  }

  @override
  String get substituteSave => 'Предложить';

  @override
  String get completeShopping => 'Завершить сборку';

  @override
  String get completeTitle => 'Завершить сборку?';

  @override
  String get completeExplained =>
      'После завершения заказ уйдёт из вашего списка и будет готов к доставке.';

  @override
  String get completeUnconfirmed =>
      'На последнее завершение нет ответа — отправим снова.';

  @override
  String completeIncomplete(String names) {
    return 'Ещё не решены: $names';
  }

  @override
  String doneTitle(String number) {
    return 'Заказ №$number собран';
  }

  @override
  String doneLabel(String number) {
    return 'Напишите на пакете номер $number и отнесите его в пункт передачи.';
  }

  @override
  String get doneBack => 'К моим заказам';

  @override
  String get errorShoppingNotActive => 'Этот заказ сейчас нельзя собирать.';

  @override
  String get errorItemAlreadyResolved => 'По этой позиции уже всё решено.';

  @override
  String get errorCustomerApprovalRequired =>
      'Для этого нужно согласие клиента.';

  @override
  String get errorApprovalNotNeeded =>
      'Для этой цены спрашивать клиента не нужно — покупайте.';

  @override
  String get errorSubstitutionNotAllowed =>
      'Клиент не разрешил заменять этот товар.';

  @override
  String get errorShoppingIncomplete => 'Есть ещё нерешённые позиции.';

  @override
  String get shopperOrderGone => 'Этот заказ больше не ваш.';

  @override
  String get shopperOrderCancelled => 'Заказ отменён: покупать больше нечего.';

  @override
  String get substituteUseBuy =>
      'Эта замена уже разрешена. Введите цену через «Купить» — там при необходимости можно спросить клиента.';

  @override
  String questionReplacementPrice(String name, String price) {
    return 'Замена «$name»: цена $price. Согласны на эту цену?';
  }

  @override
  String questionSubstitution(String name, String replacement, String price) {
    return '$name: нет в наличии. Замена — $replacement, $price. Согласны?';
  }

  @override
  String questionExpires(String time) {
    return 'Ответьте до $time';
  }

  @override
  String get questionApprove => 'Согласиться';

  @override
  String get questionReject => 'Отказаться';

  @override
  String get questionFromShopper => 'Вопрос от сборщика';

  @override
  String get questionSubstitutionTitle => 'Замена';

  @override
  String get questionLessTitle => 'Меньше, чем заказали';

  @override
  String questionPriceKit(String price, String was) {
    return 'Цена сегодня $price, при заказе была $was. Согласны на эту цену?';
  }

  @override
  String questionLessKit(String proposed, String ordered) {
    return 'Есть только $proposed, вы заказали $ordered. Согласны на меньшее?';
  }

  @override
  String questionInsteadOf(String name, String quantity) {
    return 'вместо «$name», $quantity';
  }

  @override
  String questionNoteKit(String note) {
    return 'Сборщик: «$note»';
  }

  @override
  String get questionExpiredTitle => 'Время ответа истекло';

  @override
  String get questionExpiredLine => 'Этот товар уберут из заказа';

  @override
  String decisionUnanswered(String decision) {
    return 'Ваш ответ «$decision» отправлен, но подтверждения нет. Если отправить снова, уйдёт тот же ответ.';
  }

  @override
  String get sendAgain => 'Отправить снова';

  @override
  String get requestStateApproved => 'Одобрен — заказ отменён';

  @override
  String get requestStateRejected => 'Отклонён оператором';

  @override
  String get requestStateClosed => 'Закрыт — заказ завершился иначе';

  @override
  String get orderRequestCancel => 'Попросить отменить';

  @override
  String get orderRequestCancelReason => 'Причина';

  @override
  String get errorApprovalExpired => 'Время ответа на вопрос истекло.';

  @override
  String get questionRejectRemoves =>
      'Если откажетесь, этот товар уберут из заказа.';

  @override
  String get questionDropsReplacement =>
      'Если согласитесь, купят заказанный товар, а не замену.';

  @override
  String get decisionSending => 'Отправляем ответ';

  @override
  String get courierOrdersEmpty =>
      'Пока вам не назначено доставок. Назначенная доставка появится здесь.';

  @override
  String get courierPageEmpty =>
      'На этой странице доставок не осталось. Перейдите на предыдущую.';

  @override
  String get courierNotAccepted => 'Новая доставка — примите её';

  @override
  String get courierAccept => 'Принять';

  @override
  String get courierStart => 'Выехать';

  @override
  String get courierDelivered => 'Доставлено';

  @override
  String get courierNotDelivered => 'Не доставлено';

  @override
  String get courierRequestPending =>
      'Клиент просит отменить заказ. Не выезжайте, пока оператор не решит.';

  @override
  String courierRecipient(String name) {
    return 'Получатель: $name';
  }

  @override
  String callRecipient(String phone) {
    return 'Позвонить получателю: $phone';
  }

  @override
  String callShopper(String phone) {
    return 'Позвонить сборщику: $phone';
  }

  @override
  String get courierPickupFromShopper =>
      'Пункта передачи нет — заберите заказ у сборщика.';

  @override
  String courierAddress(String address) {
    return 'Адрес: $address';
  }

  @override
  String courierLandmark(String landmark) {
    return 'Ориентир: $landmark';
  }

  @override
  String get courierAddressTitle => 'Адрес доставки';

  @override
  String courierNoteLine(String note) {
    return 'Курьеру: $note';
  }

  @override
  String get courierOpenYandex => 'Открыть в Яндексе';

  @override
  String get courierCopyAddress => 'Скопировать адрес';

  @override
  String get courierAddressCopied => 'Адрес скопирован';

  @override
  String courierMapFailed(String address) {
    return 'Не удалось открыть Яндекс. Адрес: $address';
  }

  @override
  String courierCollect(String amount) {
    return 'Получить наличными: $amount';
  }

  @override
  String get courierPaidOnline => 'Оплата онлайн — деньги не брать';

  @override
  String courierAssignedAt(String time) {
    return 'Назначена: $time';
  }

  @override
  String courierAcceptedAt(String time) {
    return 'Принята: $time';
  }

  @override
  String courierStartedAt(String time) {
    return 'Выехали: $time';
  }

  @override
  String courierDueBy(String time) {
    return 'Доставьте до $time';
  }

  @override
  String get courierDeliveredTitle => 'Заказ передан получателю?';

  @override
  String courierCashPrompt(String amount) {
    return 'Получите $amount наличными и введите полученную сумму.';
  }

  @override
  String get courierCashField => 'Получено наличными, сум';

  @override
  String get courierCashInvalid => 'Введите сумму в сумах, цифрами';

  @override
  String courierCashMismatch(String amount) {
    return 'Сумма не совпадает: нужно получить $amount.';
  }

  @override
  String get courierHandoverRepeating =>
      'Прошлая отметка осталась без ответа — отправим ту же сумму снова.';

  @override
  String get courierHandoverUnconfirmed =>
      'Отметка «Доставлено» отправлена, но ответа нет. Отправьте её снова — второй оплаты не будет.';

  @override
  String courierDeliveredDone(String number) {
    return 'Заказ $number доставлен';
  }

  @override
  String get courierNotDeliveredTitle => 'Почему не удалось доставить?';

  @override
  String get courierNotDeliveredNote => 'Комментарий';

  @override
  String get courierNotDeliveredExplained =>
      'Заказ вернётся к оператору, он решит, что с ним делать дальше.';

  @override
  String courierNotDeliveredDone(String number) {
    return 'Заказ $number возвращён оператору';
  }

  @override
  String get courierOrderGone => 'Эта доставка больше не ваша.';

  @override
  String get courierBack => 'К моим доставкам';

  @override
  String get errorDeliveryStateConflict =>
      'Доставка уже изменилась, мы обновили заказ.';

  @override
  String get errorCashAmountMismatch =>
      'Сумма не совпадает с суммой к получению.';

  @override
  String get getCodeButton => 'Получить код';

  @override
  String get codeComesInTelegram => 'Код придёт в Telegram';

  @override
  String legalEdition(String date) {
    return 'Редакция от $date';
  }

  @override
  String get legalNotPublishedYet => 'Документ пока не опубликован.';

  @override
  String consentAll(String terms, String privacy) {
    return 'Продолжая, вы принимаете $terms и $privacy';
  }

  @override
  String consentTermsOnly(String terms) {
    return 'Продолжая, вы принимаете $terms';
  }

  @override
  String consentPrivacyOnly(String privacy) {
    return 'Продолжая, вы принимаете $privacy';
  }

  @override
  String get consentTermsLink => 'Условия использования';

  @override
  String get consentPrivacyLink => 'Политику конфиденциальности';

  @override
  String get confirmPhoneTitle => 'Проверьте номер';

  @override
  String get confirmPhoneBody => 'Отправим на него код в Telegram';

  @override
  String get editButton => 'Изменить';

  @override
  String get sendButton => 'Отправить';

  @override
  String get codeTitle => 'Введите код';

  @override
  String get nameTitle => 'Как вас зовут?';

  @override
  String get nameSubtitle => 'Имя нужно сборщику и курьеру';

  @override
  String welcomeTitle(String name) {
    return 'Добро пожаловать, $name!';
  }

  @override
  String get welcomeBody => 'Свежие продукты с базара уже ждут вас';

  @override
  String get welcomeButton => 'К покупкам';

  @override
  String get staffPasswordTitle => 'Вход для сотрудника';

  @override
  String get staffPasswordSubtitle =>
      'Номер подтверждён. Введите пароль сотрудника';

  @override
  String get staffPasswordForgot =>
      'Забыли пароль? Обратитесь к администратору';

  @override
  String get staffPasswordWrong => 'Неверный пароль';

  @override
  String get staffStepExpired => 'Подтверждение истекло. Получите новый код';

  @override
  String get getNewCodeButton => 'Получить новый код';

  @override
  String get showPassword => 'Показать пароль';

  @override
  String get hidePassword => 'Скрыть пароль';

  @override
  String get back => 'Назад';

  @override
  String get wrongSurfaceWebTitle => 'Откройте приложение';

  @override
  String catalogApproxPrice(String price) {
    return '≈ $price';
  }

  @override
  String catalogPerUnit(String unit) {
    return 'за $unit';
  }

  @override
  String get catalogAdd => 'Добавить';

  @override
  String get catalogUnavailable => 'Нет в продаже';

  @override
  String get favoriteFailed => 'Не удалось сохранить. Попробуйте ещё раз';

  @override
  String get favoritesFull => 'В избранном уже 500 товаров — уберите лишние';

  @override
  String get favoriteAdd => 'Добавить в избранное';

  @override
  String get favoriteRemove => 'Убрать из избранного';

  @override
  String get cartStepMinus => 'Уменьшить';

  @override
  String get cartStepPlus => 'Увеличить';

  @override
  String get sortTitle => 'Сортировка';

  @override
  String get sortShop => 'Как в магазине';

  @override
  String get sortPriceAsc => 'Сначала дешевле';

  @override
  String get sortPriceDesc => 'Сначала дороже';

  @override
  String get allProductsTitle => 'Все товары';

  @override
  String get recommendedTitle => 'Рекомендуем';

  @override
  String get recommendedEmpty => 'Пока нет рекомендованных товаров';

  @override
  String cartSummaryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count товара',
      many: '$count товаров',
      few: '$count товара',
      one: '$count товар',
    );
    return '$_temp0';
  }

  @override
  String get cartSummaryOpen => 'В корзину';

  @override
  String get favoritesTitle => 'Избранное';

  @override
  String get favoritesEmptyTitle => 'Пока пусто';

  @override
  String get favoritesEmptyText =>
      'Нажмите сердечко на товаре — он появится здесь, и его будет легко заказать снова';

  @override
  String get favoritesEmptyAction => 'За покупками';

  @override
  String get searchRecentTitle => 'Недавние запросы';

  @override
  String get searchRecentClear => 'Очистить';

  @override
  String searchFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Найдено: $count товаров',
      few: 'Найдено: $count товара',
      one: 'Найдено: $count товар',
    );
    return '$_temp0';
  }

  @override
  String get searchNothingTitle => 'Ничего не нашли';

  @override
  String searchNothingText(String query) {
    return 'По запросу «$query» товаров нет. Проверьте написание — мы ищем и по-русски, и по-узбекски.';
  }

  @override
  String get searchAllCategories => 'Все категории';

  @override
  String get openSearch => 'Поиск';

  @override
  String get productTitle => 'О товаре';

  @override
  String get productReadMore => 'Читать далее';

  @override
  String get productReadLess => 'Свернуть';

  @override
  String get productIfMissing => 'Если товара не будет';

  @override
  String get productNoteHint => 'Например: покрепче, не перезрелые';

  @override
  String productMoreIn(String category) {
    return 'Ещё в «$category»';
  }

  @override
  String get productMoreGeneric => 'Ещё из этой категории';

  @override
  String get productAddToCart => 'В корзину';

  @override
  String get productGoneTitle => 'Товара больше нет в продаже';

  @override
  String get productGoneText =>
      'Его убрали из каталога. Похожие товары можно найти в категориях.';

  @override
  String get productGoneAction => 'В каталог';

  @override
  String productInCart(String quantity) {
    return 'В корзине: $quantity';
  }

  @override
  String get productSave => 'Сохранить';

  @override
  String get productAlreadyInCart =>
      'Этот товар уже в корзине — можно изменить и сохранить';

  @override
  String get quantitySheetTitle => 'Количество';

  @override
  String get quantitySheetDone => 'Готово';

  @override
  String cartUnitPrice(String unit, String price) {
    return '≈ $price за $unit';
  }

  @override
  String cartUnitPriceExact(String unit, String price) {
    return '$price за $unit';
  }

  @override
  String get cartRemoveTitle => 'Убрать из корзины?';

  @override
  String get cartRemoveConfirm => 'Убрать';

  @override
  String get cartEmptyTitle => 'Корзина пока пуста';

  @override
  String get cartEmptyText =>
      'Добавьте товары из каталога — сборщик купит их на рынке, курьер привезёт.';

  @override
  String cartGoods(int count) {
    return 'Товары ($count)';
  }

  @override
  String get cartDelivery => 'Доставка';

  @override
  String get cartServiceFee => 'Сервисный сбор';

  @override
  String get cartTotal => 'Итого';

  @override
  String get cartEstimateNote =>
      'Сумма ориентировочная. Итог считаем по ценам рынка после покупки; если цена выйдет выше допустимого — спросим вас.';

  @override
  String cartMinimumShort(String amount) {
    return 'До минимального заказа не хватает $amount';
  }

  @override
  String cartMinimumRule(String amount) {
    return 'Минимальная сумма товаров — $amount, без доставки и сбора';
  }

  @override
  String get cartWhyUnavailable =>
      'Сначала уберите товары, которых нет в продаже';

  @override
  String cartWhyMinimum(String amount) {
    return 'Минимальный заказ — $amount';
  }

  @override
  String get cartAddMoreTitle => 'Добавьте к заказу';

  @override
  String get cartDeliveryTo => 'Доставка:';

  @override
  String get settingsSupportPhone => 'Телефон поддержки';

  @override
  String get settingsSupportPhoneHint =>
      '+998 и 9 цифр; пусто — кнопку не показываем';

  @override
  String get fieldSupportPhone => 'Введите номер: +998 и 9 цифр';

  @override
  String get attentionLowRating => 'Низкая оценка';

  @override
  String get ratingTitle => 'Оценка клиента';

  @override
  String ratingStars(int count) {
    return 'Оценка: $count из 5';
  }

  @override
  String get ratingReasonNotFresh => 'Несвежее';

  @override
  String get ratingReasonWrongWeight => 'Не тот вес';

  @override
  String get ratingReasonLate => 'Опоздал';

  @override
  String get ratingReasonRude => 'Невежливо';

  @override
  String get ratingReview => 'Связались с клиентом';

  @override
  String ratingReviewed(String name, String time) {
    return 'Разобрано: $name, $time';
  }

  @override
  String get dayToday => 'Сегодня';

  @override
  String get dayYesterday => 'Вчера';

  @override
  String dayDate(String day, String month) {
    return '$day $month';
  }

  @override
  String monthShort(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'm1': 'янв',
      'm2': 'фев',
      'm3': 'мар',
      'm4': 'апр',
      'm5': 'мая',
      'm6': 'июн',
      'm7': 'июл',
      'm8': 'авг',
      'm9': 'сен',
      'm10': 'окт',
      'm11': 'ноя',
      'm12': 'дек',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String orderWhen(String day, String time) {
    return '$day, $time';
  }

  @override
  String orderAt(String day, String time) {
    return '$day в $time';
  }

  @override
  String get reorderTitle => 'Добавили в корзину';

  @override
  String get reorderNothingTitle => 'Ничего не добавили';

  @override
  String reorderAdded(int count, int number) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count товара из заказа № $number — по сегодняшним ценам.',
      many: '$count товаров из заказа № $number — по сегодняшним ценам.',
      few: '$count товара из заказа № $number — по сегодняшним ценам.',
      one: '$count товар из заказа № $number — по сегодняшним ценам.',
    );
    return '$_temp0';
  }

  @override
  String get reorderSkippedTitle => 'Уже были в корзине — оставили как есть';

  @override
  String reorderInCart(String quantity) {
    return 'В корзине $quantity';
  }

  @override
  String get reorderUnavailableTitle => 'Нет в продаже — не добавили';

  @override
  String get reorderCartFullTitle =>
      'Не поместились — в корзине уже 100 товаров';

  @override
  String get reorderStay => 'Остаться';

  @override
  String get reorderToCart => 'В корзину';

  @override
  String get reorderRepeat => 'Повторить';

  @override
  String get reorderRepeatOrder => 'Повторить заказ';

  @override
  String get reorderSending => 'Добавляем в корзину';

  @override
  String get questionBannerTitle => 'Сборщик ждёт вашего ответа';

  @override
  String questionBannerOrder(String number, String time) {
    return 'Заказ № $number · ответьте до $time';
  }

  @override
  String get questionAnswer => 'Ответить';

  @override
  String get ordersTabCurrent => 'Текущие';

  @override
  String get ordersTabPast => 'Прошлые';

  @override
  String customerOrderTitle(int number) {
    return 'Заказ № $number';
  }

  @override
  String orderItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count товара',
      many: '$count товаров',
      few: '$count товара',
      one: '$count товар',
    );
    return '$_temp0';
  }

  @override
  String orderCardQuestion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сборщик спрашивает про $count товара',
      many: 'Сборщик спрашивает про $count товаров',
      few: 'Сборщик спрашивает про $count товара',
      one: 'Сборщик спрашивает про $count товар',
    );
    return '$_temp0';
  }

  @override
  String get callCourier => 'Позвонить курьеру';

  @override
  String get ordersEmptyHint =>
      'Соберите корзину — сборщик купит всё на базаре, а курьер привезёт.';

  @override
  String get ordersEmptyAction => 'За покупками';

  @override
  String get ordersPastEmpty => 'Здесь будут доставленные и отменённые заказы';

  @override
  String rateStarsLabel(int stars) {
    return 'Оценить на $stars из 5';
  }

  @override
  String ratedStarsLabel(int stars) {
    return 'Оценка: $stars из 5';
  }

  @override
  String get orderStateAccepted => 'Заказ принят';

  @override
  String get orderStateAcceptedHint =>
      'Скоро сборщик начнёт покупать на базаре';

  @override
  String get orderStateShopping => 'Покупаем на базаре';

  @override
  String get orderStateShoppingHint => 'Сборщик выбирает ваши продукты';

  @override
  String get orderStateCollected => 'Заказ собран';

  @override
  String get orderStateCollectedHint => 'Скоро курьер заберёт его';

  @override
  String get orderStateOnTheWay => 'Курьер везёт заказ';

  @override
  String orderStateLeftAt(String time) {
    return 'Выехал в $time';
  }

  @override
  String get orderStateDelivered => 'Доставлен';

  @override
  String get orderStateCancelled => 'Заказ отменён';

  @override
  String orderCancelledByYou(String when) {
    return 'Вы отменили $when';
  }

  @override
  String orderCancelledWhen(String when) {
    return 'Отменён $when';
  }

  @override
  String orderCancelReasonQuoted(String reason) {
    return 'Причина: «$reason»';
  }

  @override
  String get progressAccepted => 'Принят';

  @override
  String get progressShopping => 'Покупаем';

  @override
  String get progressDelivering => 'Везём';

  @override
  String get progressDelivered => 'Доставлен';

  @override
  String get orderCanStillChange =>
      'Пока сборщик не начал, заказ можно изменить или отменить.';

  @override
  String orderLineBoughtKit(String quantity, String price) {
    return 'Куплено $quantity × $price';
  }

  @override
  String get lineTagBought => 'Куплено';

  @override
  String get lineTagWaiting => 'Ждёт вашего ответа';

  @override
  String get lineTagUnavailable => 'Не было на базаре — убрали';

  @override
  String get lineTagRejected => 'Вы отказались — убрали';

  @override
  String get lineTagExpired => 'Не ответили вовремя — убрали';

  @override
  String get lineTagOperator => 'Убрал оператор';

  @override
  String get orderToPayLabel => 'К оплате';

  @override
  String get orderNothingDue => 'нет';

  @override
  String get orderPaidCash => 'Оплачено наличными';

  @override
  String get orderPaidOnline => 'Оплачено онлайн';

  @override
  String orderPaidWhen(String amount, String when) {
    return '$amount, $when';
  }

  @override
  String orderToPayAmount(String amount) {
    return 'К оплате $amount';
  }

  @override
  String get orderCashOnDelivery => 'Наличными курьеру при получении';

  @override
  String get orderAddressTitle => 'Адрес доставки';

  @override
  String get supportTitle => 'Поддержка';

  @override
  String get supportHint => 'Если что-то пошло не так';

  @override
  String get callAction => 'Позвонить';

  @override
  String get courierYours => 'Ваш курьер';

  @override
  String get orderCancelShort => 'Отменить';

  @override
  String get requestYouAsked => 'Вы попросили отменить';

  @override
  String get requestPendingHint =>
      'Решит оператор — мы сообщим. Пока заказ в работе.';

  @override
  String cancelSheetTitle(int number) {
    return 'Отменить заказ № $number?';
  }

  @override
  String get cancelSheetHint =>
      'Сборщик ещё не начал покупать — отменим сразу.';

  @override
  String get requestSheetTitle => 'Попросить отменить?';

  @override
  String get requestSheetHint =>
      'Сборщик уже покупает. Напишите причину — решит оператор и сообщит вам.';

  @override
  String get cancelReasonHint => 'Например: заказал не то';

  @override
  String get orderCancelKeepKit => 'Не отменять';

  @override
  String get requestSend => 'Отправить';

  @override
  String get rateTitle => 'Оценка заказа';

  @override
  String rateQuestion(int number) {
    return 'Как вам заказ № $number?';
  }

  @override
  String get rateHint => 'Оцените всё: свежесть продуктов, вес и доставку';

  @override
  String get rateStar1 => 'Очень плохо';

  @override
  String get rateStar2 => 'Плохо';

  @override
  String get rateStar3 => 'Нормально';

  @override
  String get rateStar4 => 'Хорошо';

  @override
  String get rateStar5 => 'Отлично!';

  @override
  String get rateWhatWrong => 'Что пошло не так?';

  @override
  String get rateComment => 'Комментарий (необязательно)';

  @override
  String get rateCommentHintGood => 'Что понравилось?';

  @override
  String get rateCommentHintBad => 'Что случилось?';

  @override
  String get rateOperatorWillCall =>
      'Оператор увидит оценку и свяжется с вами, чтобы разобраться.';

  @override
  String get rateSend => 'Отправить';

  @override
  String get rateSending => 'Отправляем оценку';

  @override
  String get rateBlockTitle => 'Как вам заказ?';

  @override
  String get rateBlockHint => 'Свежесть, вес, доставка — оценить можно 7 дней';

  @override
  String get ratedTitle => 'Ваша оценка';

  @override
  String get ratedThanksLow =>
      'Спасибо! Оператор свяжется с вами, чтобы разобраться.';

  @override
  String get ratedThanks => 'Спасибо за оценку!';

  @override
  String get rateWindowClosed =>
      'Оценить заказ можно в течение 7 дней после доставки — это время прошло.';
}
