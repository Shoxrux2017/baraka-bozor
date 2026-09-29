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
  String get categorySaved => 'Категория сохранена';

  @override
  String get productNew => 'Новый товар';

  @override
  String get productEditTitle => 'Редактирование товара';

  @override
  String get productSaved => 'Товар сохранён';

  @override
  String get productCategory => 'Категория';

  @override
  String get productAllCategories => 'Все категории';

  @override
  String get productUnit => 'Единица измерения';

  @override
  String get productPriceMode => 'Тип цены';

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
  String get catalogSearchHint => 'Поиск товаров';

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
  String get catalogEstimateNote => 'цена ориентировочная';

  @override
  String get catalogEstimateExplain =>
      'Итоговая цена рассчитывается от цены, которую сборщик фактически заплатит на рынке. Если она превысит ориентировочную больше допустимого, мы спросим вашего согласия до покупки.';

  @override
  String get catalogLoadMore => 'Загрузить ещё';

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
  String get addressLabel => 'Название, например, Дом или Работа';

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
  String get addressMapHint =>
      'Двигайте карту, чтобы метка стояла у вашей двери';

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
  String get cartEmpty => 'Корзина пуста';

  @override
  String get cartAdd => 'В корзину';

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
  String cartSubtotal(String amount) {
    return 'Ориентировочно итого: $amount';
  }

  @override
  String cartLineEstimate(String amount) {
    return '≈ $amount';
  }

  @override
  String get cartLineUnavailable => 'Сейчас нет в продаже';

  @override
  String get cartUnavailableHint =>
      'Уберите товары, которых нет в продаже, — с ними заказ не оформить';

  @override
  String get cartRemoveLine => 'Убрать из корзины';

  @override
  String get cartSaving => 'Сохраняем';

  @override
  String get errorCartItemAlreadyExists => 'Этот товар уже в корзине';

  @override
  String get errorCartFull => 'В корзине может быть не больше 100 позиций';

  @override
  String get errorProductUnavailable => 'Этого товара сейчас нет в продаже';

  @override
  String get checkoutTitle => 'Оформление заказа';

  @override
  String get checkoutGo => 'Оформить';

  @override
  String get checkoutAddress => 'Адрес доставки';

  @override
  String get checkoutNoAddress => 'Адресов пока нет';

  @override
  String get checkoutAddAddress => 'Добавить адрес';

  @override
  String get checkoutPayment => 'Способ оплаты';

  @override
  String get checkoutOnlineUnavailable =>
      'Пока можно оплатить только наличными';

  @override
  String get checkoutCalculate => 'Рассчитать';

  @override
  String get checkoutCalculating => 'Рассчитываем';

  @override
  String get checkoutConfirm => 'Подтвердить заказ';

  @override
  String get checkoutPlacing => 'Отправляем заказ';

  @override
  String get checkoutEstimateExplain =>
      'Есть товары с ориентировочной ценой: итог станет известен, когда сборщик их купит';

  @override
  String checkoutClosedUntil(String time) {
    return 'Сейчас нерабочее время. Заказ начнут собирать с $time';
  }

  @override
  String checkoutPlaced(String number) {
    return 'Заказ №$number принят';
  }

  @override
  String get checkoutBackToCatalog => 'Вернуться в каталог';

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
      'Не удалось узнать, принят ли заказ. Нажмите «Подтвердить заказ» ещё раз — дважды он не оформится';

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
  String get orderEditTitle => 'Изменение заказа';

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
  String get orderAddedLine => 'Добавляется, по текущей цене';

  @override
  String get orderAddAlreadyIn =>
      'Этот товар уже в заказе — его можно изменить';

  @override
  String orderAddFull(int count) {
    return 'В заказе может быть не больше $count товаров';
  }

  @override
  String get orderCancel => 'Отменить заказ';

  @override
  String get orderCancelConfirm => 'Отменить заказ?';

  @override
  String get orderCancelReason => 'Причина (необязательно)';

  @override
  String get orderCancelRepeating =>
      'Прошлый запрос остался без ответа: он повторится с той же причиной';

  @override
  String get orderCancelKeep => 'Нет, оставить';

  @override
  String get orderCancelling => 'Отменяем';

  @override
  String get orderCancellationRequested => 'Отмена запрошена: решит оператор';

  @override
  String get orderCancellationNeedsReason =>
      'Покупка уже началась: напишите причину отмены, и решит оператор';

  @override
  String get orderOpen => 'Открыть заказ';

  @override
  String orderLineRemoved(String reason) {
    return 'Убрано: $reason';
  }

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
  String get ordersNeedAnswer => 'Нужен ваш ответ';

  @override
  String orderLineBought(String quantity, String price, String total) {
    return 'Куплено: $quantity × $price = $total';
  }

  @override
  String questionPrice(String name, String price, String was) {
    return '$name: цена теперь $price (было $was). Согласны на эту цену?';
  }

  @override
  String questionReplacementPrice(String name, String price) {
    return 'Замена «$name»: цена $price. Согласны на эту цену?';
  }

  @override
  String questionSubstitution(String name, String replacement, String price) {
    return '$name: нет в наличии. Замена — $replacement, $price. Согласны?';
  }

  @override
  String questionQuantity(String name, String proposed, String ordered) {
    return '$name: есть только $proposed, вы заказали $ordered. Согласны на меньшее?';
  }

  @override
  String questionNote(String note) {
    return 'Комментарий сборщика: $note';
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
  String get questionExpired =>
      'Время ответа истекло — этот товар уберут из заказа.';

  @override
  String decisionUnanswered(String decision) {
    return 'Ваш ответ «$decision» отправлен, но подтверждения нет. Если отправить снова, уйдёт тот же ответ.';
  }

  @override
  String get sendAgain => 'Отправить снова';

  @override
  String orderPaid(String amount, String time) {
    return 'Оплачено: $amount, $time';
  }

  @override
  String requestYours(String reason) {
    return 'Ваш запрос на отмену: $reason';
  }

  @override
  String get requestStateApproved => 'Одобрен — заказ отменён';

  @override
  String get requestStateRejected => 'Отклонён — заказ выполняется';

  @override
  String get requestStateClosed => 'Закрыт — заказ завершился иначе';

  @override
  String get orderRequestCancel => 'Попросить отменить';

  @override
  String get orderRequestCancelTitle => 'Попросить отменить заказ?';

  @override
  String get orderRequestCancelReason => 'Причина';

  @override
  String get orderRequestCancelExplained => 'Сборка уже идёт — решит оператор.';

  @override
  String get errorApprovalExpired => 'Время ответа на вопрос истекло.';

  @override
  String get questionRejectRemoves =>
      'Если откажетесь, этот товар уберут из заказа.';

  @override
  String get removedYouRejected => 'вы отказались';

  @override
  String get removedYouRemoved => 'вы убрали';
}
