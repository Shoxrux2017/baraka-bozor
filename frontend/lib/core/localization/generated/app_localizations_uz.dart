// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appTitle => 'BarakaBozor';

  @override
  String get customerLoginTitle => 'Kirish';

  @override
  String get customerLoginIntro =>
      'Telefon raqamingizni kiriting, biz sizga kirish kodini yuboramiz';

  @override
  String get phoneLabel => 'Telefon raqami';

  @override
  String get phoneHint => '90 123 45 67';

  @override
  String get phoneInvalid => 'Raqamning 9 ta raqamini kiriting';

  @override
  String get continueButton => 'Davom etish';

  @override
  String get codeSentTelegram => 'Kod Telegram orqali yuborildi';

  @override
  String get codeSentSms => 'Kod SMS orqali yuborildi';

  @override
  String get codeSentGeneric => 'Kod yuborildi';

  @override
  String get codeLabel => 'Kirish kodi';

  @override
  String get codeInvalidFormat => '6 ta raqamdan iborat kodni kiriting';

  @override
  String get verifyButton => 'Tasdiqlash';

  @override
  String get resendCode => 'Kodni qayta yuborish';

  @override
  String resendIn(int seconds) {
    return 'Qayta yuborish $seconds soniyadan so\'ng';
  }

  @override
  String get changePhone => 'Raqamni o\'zgartirish';

  @override
  String codeSentToPhone(String phone) {
    return 'Kod $phone raqamiga yuborildi';
  }

  @override
  String get customerModeIntro =>
      'Mijoz rejimiga kirish uchun o\'z raqamingizga yuborilgan kodni kiriting';

  @override
  String get cancelButton => 'Bekor qilish';

  @override
  String get requestCodeButton => 'Kod so\'rash';

  @override
  String get wrongSurfaceTitle => 'Bu yerdan kirib bo\'lmaydi';

  @override
  String get staffLoginTitle => 'Xodim kirishi';

  @override
  String get staffLoginLink => 'Xodim sifatida kirish';

  @override
  String get customerLoginLink => 'Mijoz sifatida kirish';

  @override
  String get passwordLabel => 'Parol';

  @override
  String get passwordRequired => 'Parolni kiriting';

  @override
  String get loginButton => 'Kirish';

  @override
  String get changePasswordTitle => 'Parolni o\'zgartirish';

  @override
  String get changePasswordRequiredIntro =>
      'Davom etishdan oldin vaqtinchalik parolni o\'zingiznikiga almashtiring';

  @override
  String get currentPasswordLabel => 'Joriy parol';

  @override
  String get newPasswordLabel => 'Yangi parol';

  @override
  String get confirmPasswordLabel => 'Yangi parolni takrorlang';

  @override
  String get passwordRuleHint => '10 tadan 128 tagacha belgi';

  @override
  String get passwordsDoNotMatch => 'Parollar mos kelmadi';

  @override
  String get savePasswordButton => 'Saqlash';

  @override
  String get passwordChanged => 'Parol o\'zgartirildi';

  @override
  String get logoutButton => 'Chiqish';

  @override
  String get wrongSurfaceMobile =>
      'Bu hisob veb-panelda ishlaydi. Kompyuterdagi brauzer orqali kiring.';

  @override
  String get wrongSurfaceWeb =>
      'Bu hisob mobil ilovada ishlaydi. Telefondagi BarakaBozor ilovasi orqali kiring.';

  @override
  String get languageLabel => 'Til';

  @override
  String get languageUzbek => 'O\'zbekcha';

  @override
  String get languageRussian => 'Русский';

  @override
  String get retryButton => 'Qayta urinish';

  @override
  String get shellCustomer => 'Mijoz';

  @override
  String get shellShopper => 'Yig\'uvchi';

  @override
  String get shellCourier => 'Kuryer';

  @override
  String get shellOperations => 'Operatsiyalar';

  @override
  String get shellAdmin => 'Administrator';

  @override
  String get shellManager => 'Menejer';

  @override
  String get shellPlaceholder => 'Bu bo\'lim keyingi bosqichda paydo bo\'ladi';

  @override
  String get panelSectionBoard => 'Buyurtmalar';

  @override
  String get customerModeLabel => 'Mijoz rejimi';

  @override
  String get staffModeLabel => 'Xodim rejimi';

  @override
  String get switchToCustomer => 'Mijoz sifatida davom etish';

  @override
  String get switchToStaff => 'Xodim rejimiga qaytish';

  @override
  String get sessionUnreachableTitle => 'Server bilan aloqa yo\'q';

  @override
  String get sessionUnreachableBody =>
      'Internet aloqasini tekshiring va qayta urinib ko\'ring';

  @override
  String get errorAuthenticationRequired => 'Qaytadan kiring';

  @override
  String get errorAccountBlocked => 'Bu hisob bloklangan';

  @override
  String get errorInvalidCredentials => 'Telefon raqami yoki parol noto\'g\'ri';

  @override
  String get errorCodeInvalid => 'Kod noto\'g\'ri';

  @override
  String get errorCodeExpired => 'Kod muddati tugadi. Yangi kod so\'rang';

  @override
  String get errorCodeAttemptsExhausted =>
      'Urinishlar soni tugadi. Yangi kod so\'rang';

  @override
  String get errorCodeResendTooSoon =>
      'Kodni qayta yuborishdan oldin biroz kuting';

  @override
  String get errorRateLimited => 'Urinishlar juda ko\'p. Biroz kutib turing';

  @override
  String get errorProviderUnavailable =>
      'Xizmat vaqtincha ishlamayapti. Keyinroq urinib ko\'ring';

  @override
  String get errorServiceUnavailable =>
      'Texnik ishlar olib borilmoqda. Keyinroq urinib ko\'ring';

  @override
  String get errorServerError => 'Kutilmagan xatolik. Keyinroq urinib ko\'ring';

  @override
  String get errorNetwork => 'Internet aloqasi yo\'q';

  @override
  String get errorValidationFailed => 'Kiritilgan ma\'lumotlarni tekshiring';

  @override
  String get errorForbidden => 'Bu amalga ruxsat yo\'q';

  @override
  String get errorNotFound => 'Topilmadi';

  @override
  String get errorPasswordChangeRequired => 'Avval parolni o\'zgartiring';

  @override
  String get errorUnknown => 'Xatolik yuz berdi. Qayta urinib ko\'ring';

  @override
  String get adminSectionSettings => 'Sozlamalar';

  @override
  String get saveButton => 'Saqlash';

  @override
  String get settingsTitle => 'Biznes sozlamalari';

  @override
  String get settingsPricingSection => 'Narxlar va yig\'imlar';

  @override
  String get settingsMarkup => 'Ustama, %';

  @override
  String get settingsServiceFeeMode => 'Xizmat haqi';

  @override
  String get settingsServiceFeeFixed => 'Belgilangan summa';

  @override
  String get settingsServiceFeePercentage => 'Buyurtmaning foizi';

  @override
  String get settingsServiceFeeAmount => 'Xizmat haqi summasi';

  @override
  String get settingsServiceFeePercent => 'Xizmat haqi, %';

  @override
  String get settingsDeliveryFee => 'Yetkazib berish narxi';

  @override
  String get settingsMinimumOrder => 'Eng kam buyurtma summasi';

  @override
  String get settingsPriceTolerance => 'Narx oshishi chegarasi, %';

  @override
  String get settingsPriceToleranceHint =>
      'Narx bundan ko\'proq oshsa, mijozning roziligi so\'raladi';

  @override
  String get settingsOptionalHint => 'Bo\'sh qoldirilsa, o\'rnatilmagan';

  @override
  String get settingsHoursSection => 'Ish vaqti';

  @override
  String get settingsOpensAt => 'Ochilish vaqti';

  @override
  String get settingsClosesAt => 'Yopilish vaqti';

  @override
  String get settingsAreaSection => 'Yetkazib berish hududi';

  @override
  String get settingsCentreLatitude => 'Markaz kengligi';

  @override
  String get settingsCentreLongitude => 'Markaz uzunligi';

  @override
  String get settingsRadius => 'Radius, km';

  @override
  String get settingsDeliverySection => 'Yetkazib berish nazorati';

  @override
  String get settingsDelayThreshold => 'Kechikish chegarasi, daqiqa';

  @override
  String get settingsSaved => 'Sozlamalar saqlandi';

  @override
  String get settingsNoChanges => 'O\'zgarish yo\'q';

  @override
  String get settingsSaving => 'Saqlanmoqda';

  @override
  String get settingsTashkentTimeHint => 'Toshkent vaqti bilan';

  @override
  String settingsUpdatedAt(String when) {
    return 'Oxirgi o\'zgarish: $when';
  }

  @override
  String get providersTitle => 'Onlayn to\'lov';

  @override
  String get providersIntro =>
      'Yoqilgan tizimlar mijozga to\'lov usuli sifatida taklif qilinadi';

  @override
  String get fieldRequired => 'Maydonni to\'ldiring';

  @override
  String get fieldPercent =>
      '0 dan 999.99 gacha son, nuqtadan keyin ko\'pi bilan 2 raqam';

  @override
  String get fieldAmount => '0 dan 1 000 000 000 gacha butun son';

  @override
  String get fieldTime => 'Vaqtni 09:00 ko\'rinishida kiriting';

  @override
  String get fieldLatitude =>
      '-90 dan 90 gacha, nuqtadan keyin ko\'pi bilan 6 raqam';

  @override
  String get fieldLongitude =>
      '-180 dan 180 gacha, nuqtadan keyin ko\'pi bilan 6 raqam';

  @override
  String get fieldRadius =>
      '0 dan katta va 9999.99 gacha, nuqtadan keyin ko\'pi bilan 2 raqam';

  @override
  String get fieldMinutes => '1 dan 1440 gacha butun son';

  @override
  String get fieldPairIncomplete =>
      'Ikkala qiymatni kiriting yoki ikkalasini ham bo\'sh qoldiring';

  @override
  String get fieldSameTime =>
      'Yopilish vaqti ochilish vaqtidan farq qilishi kerak';

  @override
  String get fieldRejected => 'Server bu qiymatni qabul qilmadi';

  @override
  String get adminSectionCategories => 'Kategoriyalar';

  @override
  String get adminSectionProducts => 'Mahsulotlar';

  @override
  String get catalogNameUz => 'Nomi (o\'zbekcha)';

  @override
  String get catalogNameRu => 'Nomi (ruscha)';

  @override
  String get catalogDescriptionUz => 'Tavsif (o\'zbekcha)';

  @override
  String get catalogDescriptionRu => 'Tavsif (ruscha)';

  @override
  String get catalogSortOrder => 'Tartib raqami';

  @override
  String get catalogSortOrderHint => 'Kichigi ro\'yxatda yuqoriroq turadi';

  @override
  String get catalogShownToCustomers => 'Mijozlarga ko\'rsatilsin';

  @override
  String get catalogIncludeArchived => 'Arxivdagilar ham';

  @override
  String get catalogStateActive => 'Ko\'rsatilmoqda';

  @override
  String get catalogStateHidden => 'Yashirilgan';

  @override
  String get catalogStateArchived => 'Arxivda';

  @override
  String get catalogEdit => 'Tahrirlash';

  @override
  String get catalogArchive => 'Arxivlash';

  @override
  String get catalogRestore => 'Arxivdan qaytarish';

  @override
  String get catalogArchivedNote =>
      'Arxivdagi yozuv mijozlarga ko\'rinmaydi. Qaytarish uchun ro\'yxatdagi amaldan foydalaning';

  @override
  String get catalogEmpty => 'Hech narsa topilmadi';

  @override
  String catalogPage(int page, int last) {
    return '$page-sahifa, jami $last';
  }

  @override
  String get catalogPreviousPage => 'Oldingi sahifa';

  @override
  String get catalogNextPage => 'Keyingi sahifa';

  @override
  String get categoryNew => 'Yangi kategoriya';

  @override
  String get categoryEditTitle => 'Kategoriyani tahrirlash';

  @override
  String get categorySaved => 'Kategoriya saqlandi';

  @override
  String get productNew => 'Yangi mahsulot';

  @override
  String get productEditTitle => 'Mahsulotni tahrirlash';

  @override
  String get productSaved => 'Mahsulot saqlandi';

  @override
  String get productCategory => 'Kategoriya';

  @override
  String get productAllCategories => 'Barcha kategoriyalar';

  @override
  String get productUnit => 'O\'lchov birligi';

  @override
  String get productPriceMode => 'Narx turi';

  @override
  String get productMarketPrice => 'Bozor narxi';

  @override
  String productCustomerPrice(String price) {
    return 'Mijoz uchun narx: $price';
  }

  @override
  String get productSearch => 'Nomi bo\'yicha qidirish';

  @override
  String get productBackToList => 'Mahsulotlar ro\'yxati';

  @override
  String get productImage => 'Rasm';

  @override
  String get productNoImage => 'Rasm yo\'q';

  @override
  String get productChooseImage => 'Rasm tanlash';

  @override
  String get productUploadImage => 'Yuklash';

  @override
  String get productRemoveImage => 'Rasmni o\'chirish';

  @override
  String get productRemoveImageConfirm => 'Mahsulot rasmi o\'chirilsinmi?';

  @override
  String get productImageRules => 'JPEG, PNG yoki WebP, ko\'pi bilan 5 MB';

  @override
  String get productImageTooLarge => 'Rasm 5 MB dan katta';

  @override
  String get productImageWrongType => 'Faqat JPEG, PNG yoki WebP rasm';

  @override
  String get productImageUnreadable =>
      'Faylni o\'qib bo\'lmadi. Boshqa faylni tanlang';

  @override
  String get productImageAfterSave =>
      'Rasmni mahsulot saqlangandan keyin qo\'shish mumkin';

  @override
  String get priceModeFixed => 'Aniq narx';

  @override
  String get priceModeEstimate => 'Taxminiy narx';

  @override
  String get unitKg => 'kg';

  @override
  String get unitGram => 'g';

  @override
  String get unitPiece => 'dona';

  @override
  String get unitLiter => 'l';

  @override
  String get unitPackage => 'qadoq';

  @override
  String get unitBox => 'quti';

  @override
  String get unitBundle => 'bog\'';

  @override
  String get unitMeter => 'm';

  @override
  String fieldTooLong(int max) {
    return 'Ko\'pi bilan $max ta belgi';
  }

  @override
  String get fieldSortOrder => '-100 000 dan 100 000 gacha butun son';

  @override
  String get fieldMarketPrice => '1 dan 1 000 000 000 gacha butun son';

  @override
  String get errorBusinessConflict =>
      'Ma\'lumot allaqachon o\'zgargan. Joriy holatni tekshirib, qayta urinib ko\'ring';

  @override
  String get errorPayloadTooLarge => 'Fayl juda katta';

  @override
  String get adminSectionStaff => 'Xodimlar';

  @override
  String get roleShopper => 'Yig\'uvchi';

  @override
  String get roleCourier => 'Kuryer';

  @override
  String get roleOperator => 'Operator';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get roleManager => 'Menejer';

  @override
  String get statusActive => 'Faol';

  @override
  String get statusBlocked => 'Bloklangan';

  @override
  String get staffNew => 'Yangi xodim';

  @override
  String get staffFullName => 'To\'liq ism';

  @override
  String get staffRole => 'Rol';

  @override
  String get staffAllRoles => 'Barcha rollar';

  @override
  String get staffAllStatuses => 'Barcha holatlar';

  @override
  String get staffNoName => 'Ism kiritilmagan';

  @override
  String get staffYou => 'Siz';

  @override
  String get staffEditName => 'Ismni o\'zgartirish';

  @override
  String get staffBlock => 'Bloklash';

  @override
  String get staffActivate => 'Blokdan chiqarish';

  @override
  String get staffResetPassword => 'Parolni tiklash';

  @override
  String staffBlockConfirm(String name) {
    return '$name bloklansinmi? Bu xodimning barcha seanslari darhol yopiladi.';
  }

  @override
  String staffResetConfirm(String name) {
    return '$name uchun yangi vaqtinchalik parol yaratilsinmi? Bu xodimning barcha seanslari yopiladi.';
  }

  @override
  String get staffTemporaryPasswordTitle => 'Vaqtinchalik parol';

  @override
  String get staffTemporaryPasswordWarning =>
      'Parolni hozir nusxalab, xodimga bering. U boshqa ko\'rsatilmaydi. Birinchi kirishda xodim o\'z parolini o\'rnatadi.';

  @override
  String get staffCopy => 'Nusxalash';

  @override
  String get staffCopied => 'Nusxalandi';

  @override
  String get staffDone => 'Tayyor';

  @override
  String get staffMustChangePassword => 'Parolni almashtirishi kerak';

  @override
  String staffLastLogin(String when) {
    return 'Oxirgi kirish: $when';
  }

  @override
  String get staffNeverLoggedIn => 'Hali kirmagan';

  @override
  String get staffSaved => 'Saqlandi';

  @override
  String get errorSelfBlockNotAllowed => 'O\'zingizni bloklay olmaysiz';

  @override
  String get errorLastActiveAdminRequired =>
      'Oxirgi faol administratorni bloklab bo\'lmaydi';

  @override
  String get errorSelfResetNotAllowed =>
      'O\'z parolingizni bu yerda tiklab bo\'lmaydi';

  @override
  String get errorPhoneAlreadyActive => 'Bu raqam boshqa faol xodimga tegishli';

  @override
  String get catalogSearchHint => 'Mahsulot qidirish';

  @override
  String get catalogSearchClear => 'Tozalash';

  @override
  String get catalogCategoriesTitle => 'Bo\'limlar';

  @override
  String get catalogNoProducts => 'Bu yerda hozircha mahsulot yo\'q';

  @override
  String catalogPricePerUnit(String price, String unit) {
    return '$price / $unit';
  }

  @override
  String get catalogEstimateNote => 'narx taxminiy';

  @override
  String get catalogEstimateExplain =>
      'Yakuniy narx yig\'uvchi bozorda haqiqatda to\'lagan narxdan hisoblanadi. U taxminiy narxdan belgilangan chegaradan ko\'proq oshsa, xarid qilishdan oldin sizdan rozilik so\'raymiz.';

  @override
  String get catalogLoadMore => 'Yana yuklash';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileName => 'Ismingiz';

  @override
  String get profileNameNeeded => 'Buyurtma berish uchun ismingizni kiriting';

  @override
  String get profileSaved => 'Ism saqlandi';

  @override
  String get addressesTitle => 'Manzillarim';

  @override
  String get addressNone => 'Hali manzil qo\'shilmagan';

  @override
  String get addressNew => 'Yangi manzil';

  @override
  String get addressEdit => 'Manzilni tahrirlash';

  @override
  String get addressLabel => 'Nomi, masalan, Uy yoki Ish';

  @override
  String get addressStreet => 'Ko\'cha';

  @override
  String get addressHouse => 'Uy';

  @override
  String get addressApartment => 'Xonadon';

  @override
  String get addressLandmark => 'Mo\'ljal';

  @override
  String get addressDeliveryNote => 'Kuryer uchun izoh';

  @override
  String get addressMapHint =>
      'Xaritani suring: belgi eshigingiz ustida tursin';

  @override
  String get addressMapUnavailable =>
      'Bu ilova versiyasida xarita yo\'q. Nuqtaning koordinatalarini kiriting';

  @override
  String get addressLatitude => 'Kenglik';

  @override
  String get addressLongitude => 'Uzunlik';

  @override
  String get addressLatitudeInvalid =>
      'Kenglik -90 dan 90 gacha son bo\'lishi kerak';

  @override
  String get addressLongitudeInvalid =>
      'Uzunlik -180 dan 180 gacha son bo\'lishi kerak';

  @override
  String get addressOutsideAreaPlain =>
      'Bu manzil yetkazib berish hududidan tashqarida';

  @override
  String get noChanges => 'O\'zgarish yo\'q';

  @override
  String addressOutsideArea(String distance, String max) {
    return 'Bu manzil yetkazib berish hududidan tashqarida: $distance km. Biz $max km gacha yetkazib beramiz';
  }

  @override
  String get addressSaved => 'Manzil saqlandi';

  @override
  String get addressRemove => 'O\'chirish';

  @override
  String get addressRemoveConfirm => 'Bu manzil o\'chirilsinmi?';

  @override
  String get errorConfigurationIncomplete =>
      'Xizmat hali to\'liq sozlanmagan. Keyinroq urinib ko\'ring';

  @override
  String get orderStatusNew => 'Yangi';

  @override
  String get orderStatusShoppingAssigned => 'Yig\'uvchi tayinlangan';

  @override
  String get orderStatusShopping => 'Yig\'ilmoqda';

  @override
  String get orderStatusFinalPaymentPending => 'To\'lov kutilmoqda';

  @override
  String get orderStatusReadyForDelivery => 'Yetkazishga tayyor';

  @override
  String get orderStatusDeliveryAssigned => 'Kuryer tayinlangan';

  @override
  String get orderStatusOnTheWay => 'Yo\'lda';

  @override
  String get orderStatusCompleted => 'Yakunlangan';

  @override
  String get orderStatusCancelled => 'Bekor qilingan';

  @override
  String get paymentCash => 'Naqd pul';

  @override
  String get paymentOnline => 'Onlayn';

  @override
  String get totalKindEstimate => 'taxminiy';

  @override
  String get totalKindFinal => 'yakuniy';

  @override
  String get totalNothingDue => 'To\'lanmaydi';

  @override
  String get itemStatusPending => 'Kutilmoqda';

  @override
  String get itemStatusAwaitingCustomer => 'Mijoz javobi kutilmoqda';

  @override
  String get itemStatusPurchased => 'Sotib olindi';

  @override
  String get itemStatusRemoved => 'Olib tashlandi';

  @override
  String get substitutionAllowSimilar => 'O\'xshashi bilan almashtirish mumkin';

  @override
  String get substitutionContactBefore => 'Almashtirishdan oldin bog\'lanish';

  @override
  String get substitutionRemoveIfUnavailable => 'Bo\'lmasa, olib tashlash';

  @override
  String get removedUnavailable => 'mahsulot topilmadi';

  @override
  String get removedCustomerRejected => 'mijoz rad etdi';

  @override
  String get removedApprovalExpired => 'javob muddati o\'tdi';

  @override
  String get removedCustomerRemoved => 'mijoz olib tashladi';

  @override
  String get removedOperatorRemoved => 'operator olib tashladi';

  @override
  String get removedOrderCancelled => 'buyurtma bekor qilindi';

  @override
  String get cancelCustomerCancelled => 'Mijoz bekor qildi';

  @override
  String get cancelRequestApproved => 'Bekor qilish so\'rovi qabul qilindi';

  @override
  String get cancelUnpaidOnline => 'Onlayn to\'lov qilinmadi';

  @override
  String get cancelNoItemsPurchased => 'Hech narsa sotib olinmadi';

  @override
  String get cancelDeliveryFailed => 'Yetkazib bo\'lmadi';

  @override
  String get cancelSystem => 'Tizim bekor qildi';

  @override
  String get boardRefresh => 'Yangilash';

  @override
  String get boardSearch => 'Raqam, telefon yoki ism';

  @override
  String get boardAllStatuses => 'Barcha holatlar';

  @override
  String get boardAllPaymentMethods => 'Barcha to\'lov usullari';

  @override
  String get boardAllShoppers => 'Barcha yig\'uvchilar';

  @override
  String get boardDays => 'Sanalar';

  @override
  String get boardClearDays => 'Sanalarni tozalash';

  @override
  String get boardSelfOrdersOnly => 'Faqat o\'zi uchun buyurtmalar';

  @override
  String get boardClearFilters => 'Filtrlarni tozalash';

  @override
  String get boardEmpty => 'Hozircha buyurtma yo\'q';

  @override
  String get boardEmptyFiltered => 'Filtrlarga mos buyurtma yo\'q';

  @override
  String get boardColumnNumber => 'Raqam';

  @override
  String get boardColumnPlaced => 'Vaqt';

  @override
  String get boardColumnCustomer => 'Mijoz';

  @override
  String get boardColumnStatus => 'Holat';

  @override
  String get boardColumnPayment => 'To\'lov';

  @override
  String get boardColumnTotal => 'Summa';

  @override
  String boardItemCount(int count) {
    return '$count ta mahsulot';
  }

  @override
  String get boardNoShopper => 'Tayinlanmagan';

  @override
  String boardOrderNumber(String number) {
    return '№$number';
  }

  @override
  String get selfOrderMark => 'O\'zi uchun';

  @override
  String get selfOrderExplained => 'Yig\'uvchi — buyurtmachining o\'zi';

  @override
  String get summaryCompletedToday => 'Bugun yakunlangan';

  @override
  String get summaryCancelledToday => 'Bugun bekor qilingan';

  @override
  String get summarySalesToday => 'Bugungi savdo';

  @override
  String get summaryAttention => 'E\'tibor talab';

  @override
  String get attentionTitle => 'E\'tibor talab qiladi';

  @override
  String get attentionEmpty => 'Hozircha hech narsa yo\'q';

  @override
  String get attentionApprovalPending =>
      'Mijoz 10 daqiqadan beri javob bermayapti — qo\'ng\'iroq qiling';

  @override
  String get attentionApprovalExpired =>
      'Mijozning javob muddati o\'tdi — mahsulotni olib tashlang';

  @override
  String get attentionPaymentOverdue => 'Onlayn to\'lov kechikmoqda';

  @override
  String get attentionRefundOutstanding => 'Pulni qaytarish kutilmoqda';

  @override
  String get attentionCourierDelayed => 'Kuryer kechikmoqda';

  @override
  String get attentionDeliveryFailed =>
      'Yetkazib bo\'lmadi — kuryer tayinlang yoki bekor qiling';

  @override
  String get attentionCancellationRequest => 'Mijoz bekor qilishni so\'ramoqda';

  @override
  String get attentionStaffBlocked =>
      'Ijrochi bloklangan — boshqasini tayinlang';

  @override
  String get attentionOther => 'E\'tibor talab qiladi';

  @override
  String attentionSince(String time) {
    return '$time dan beri';
  }

  @override
  String orderTitle(String number) {
    return 'Buyurtma №$number';
  }

  @override
  String get orderBackToBoard => 'Buyurtmalarga qaytish';

  @override
  String orderPlacedAt(String time) {
    return 'Qabul qilingan: $time';
  }

  @override
  String orderCompletedAt(String time) {
    return 'Yakunlangan: $time';
  }

  @override
  String orderCancelledAt(String time) {
    return 'Bekor qilingan: $time';
  }

  @override
  String get orderSectionCustomer => 'Mijoz';

  @override
  String get orderSectionAddress => 'Manzil';

  @override
  String get orderSectionDeliveryWish => 'Yetkazish vaqti bo\'yicha istak';

  @override
  String get orderSectionItems => 'Mahsulotlar';

  @override
  String get orderSectionTotals => 'Hisob';

  @override
  String get orderSectionShoppers => 'Yig\'uvchilar';

  @override
  String get orderSectionHistory => 'Tarix';

  @override
  String get orderNoDeliveryWish => 'Istak yo\'q';

  @override
  String orderCoordinates(String latitude, String longitude) {
    return 'Koordinatalar: $latitude, $longitude';
  }

  @override
  String itemMarketPrice(String price) {
    return 'Bozor narxi: $price';
  }

  @override
  String itemCustomerPrice(String price) {
    return 'Mijoz narxi: $price';
  }

  @override
  String itemMarkup(String percent) {
    return 'Ustama: $percent%';
  }

  @override
  String itemLineTotal(String amount) {
    return 'Summa: $amount';
  }

  @override
  String itemNote(String note) {
    return 'Izoh: $note';
  }

  @override
  String itemRemovedBecause(String reason) {
    return 'Olib tashlandi: $reason';
  }

  @override
  String get totalsMerchandise => 'Mahsulotlar';

  @override
  String get totalsServiceFee => 'Xizmat haqi';

  @override
  String get totalsDeliveryFee => 'Yetkazib berish';

  @override
  String get totalsTotal => 'Jami';

  @override
  String get assignmentCurrent => 'Hozirgi';

  @override
  String assignmentAssignedBy(String name, String time) {
    return '$name tayinladi, $time';
  }

  @override
  String assignmentAccepted(String time) {
    return 'Qabul qildi: $time';
  }

  @override
  String assignmentStarted(String time) {
    return 'Yig\'ishni boshladi: $time';
  }

  @override
  String assignmentEnded(String time, String reason) {
    return 'Tugadi: $time, $reason';
  }

  @override
  String get assignmentEndCompleted => 'yig\'ish yakunlandi';

  @override
  String get assignmentEndReassigned => 'boshqa yig\'uvchiga o\'tkazildi';

  @override
  String get assignmentEndOrderCancelled => 'buyurtma bekor qilindi';

  @override
  String get assignmentsNone => 'Yig\'uvchi hali tayinlanmagan';

  @override
  String get personWithoutName => 'Ismsiz';

  @override
  String get historyNone => 'Tarix hali bo\'sh';

  @override
  String get historySystem => 'Tizim';

  @override
  String get historyPaymentProvider => 'To\'lov tizimi';

  @override
  String get historyEventStatusChanged => 'Holat o\'zgardi';

  @override
  String get historyEventEdited => 'Buyurtma o\'zgartirildi';

  @override
  String get historyEventPaymentMethodSwitched => 'To\'lov usuli almashtirildi';

  @override
  String get historyEventPriceCorrected => 'Narx tuzatildi';

  @override
  String get historyEventShopperAssigned => 'Yig\'uvchi tayinlandi';

  @override
  String get historyEventShopperReassigned => 'Yig\'uvchi almashtirildi';

  @override
  String get historyEventCourierAssigned => 'Kuryer tayinlandi';

  @override
  String get historyEventCourierReassigned => 'Kuryer almashtirildi';

  @override
  String get historyEventDeliveryFailed => 'Yetkazib bo\'lmadi';

  @override
  String get historyEventApprovalRequested => 'Mijozdan tasdiq so\'raldi';

  @override
  String get historyEventApprovalDecided => 'Mijoz javob berdi';

  @override
  String get historyEventApprovalExpired => 'Javob muddati o\'tdi';

  @override
  String get historyEventApprovalResolved => 'Tasdiq yopildi';

  @override
  String get historyEventShopperAccepted => 'Yig\'uvchi buyurtmani qabul qildi';

  @override
  String get historyEventCourierAccepted => 'Kuryer buyurtmani qabul qildi';

  @override
  String get historyEventItemPurchased => 'Mahsulot sotib olindi';

  @override
  String get historyEventItemUnavailable => 'Mahsulot topilmadi';

  @override
  String get historyEventItemSubstituted => 'Mahsulot almashtirildi';

  @override
  String get historyEventCancellationRequested =>
      'Mijoz bekor qilishni so\'radi';

  @override
  String get historyEventCancellationRequestDecided =>
      'Bekor qilish so\'rovi ko\'rib chiqildi';

  @override
  String get historyEventPaymentRecorded => 'To\'lov qabul qilindi';

  @override
  String get historyDeliveryWishChanged => 'yetkazish istagi o\'zgardi';

  @override
  String historyAssignedTo(String name) {
    return 'Yig\'uvchi: $name';
  }

  @override
  String historyEditAdded(int count) {
    return 'qo\'shildi: $count';
  }

  @override
  String historyEditRemoved(int count) {
    return 'olib tashlandi: $count';
  }

  @override
  String historyEditChanged(int count) {
    return 'o\'zgartirildi: $count';
  }

  @override
  String historyReassignedTo(String previous, String name) {
    return 'Yig\'uvchi: $previous → $name';
  }

  @override
  String get boardFilteredShopper => 'Tanlangan yig\'uvchi';

  @override
  String get boardFilterStatus => 'Holat';

  @override
  String get boardFilterPayment => 'To\'lov usuli';

  @override
  String get boardFilterShopper => 'Yig\'uvchi';

  @override
  String get errorOrderStateConflict =>
      'Buyurtma allaqachon o\'zgargan va yangilandi. Uni ko\'rib chiqib, qayta urinib ko\'ring';

  @override
  String get errorStaffNotActive => 'Bu xodim bloklangan. Boshqasini tanlang';

  @override
  String get assignShopper => 'Yig\'uvchi tayinlash';

  @override
  String get reassignShopper => 'Yig\'uvchini almashtirish';

  @override
  String get pickShopperTitle => 'Yig\'uvchini tanlang';

  @override
  String get pickShopperEmpty => 'Faol yig\'uvchilar yo\'q';

  @override
  String shopperOrdersNow(int count) {
    return 'Hozir $count ta buyurtma';
  }

  @override
  String get assigningShopper => 'Yig\'uvchi tayinlanmoqda';

  @override
  String get cartTitle => 'Savat';

  @override
  String get cartOpen => 'Savatni ochish';

  @override
  String cartBadge(int count) {
    return 'Savat: $count';
  }

  @override
  String get cartEmpty => 'Savat bo\'sh';

  @override
  String get cartAdd => 'Savatga qo\'shish';

  @override
  String get cartAdded => 'Savatga qo\'shildi';

  @override
  String get cartQuantity => 'Miqdori';

  @override
  String get cartQuantityFraction =>
      '0 dan katta son: ko\'pi bilan 4 xona va 3 kasr';

  @override
  String get cartQuantityWhole => '1 dan 9999 gacha butun son';

  @override
  String get cartDecrease => 'Kamaytirish';

  @override
  String get cartIncrease => 'Ko\'paytirish';

  @override
  String get cartNote => 'Yig\'uvchi uchun izoh';

  @override
  String get cartSubstitution => 'Mahsulot bo\'lmasa';

  @override
  String cartSubtotal(String amount) {
    return 'Taxminiy jami: $amount';
  }

  @override
  String cartLineEstimate(String amount) {
    return '≈ $amount';
  }

  @override
  String get cartLineUnavailable => 'Hozir sotuvda yo\'q';

  @override
  String get cartUnavailableHint =>
      'Sotuvda yo\'q mahsulotlarni olib tashlang — ular bilan buyurtma berib bo\'lmaydi';

  @override
  String get cartRemoveLine => 'Savatdan olib tashlash';

  @override
  String get cartSaving => 'Saqlanmoqda';

  @override
  String get errorCartItemAlreadyExists => 'Bu mahsulot allaqachon savatda';

  @override
  String get errorCartFull =>
      'Savatda ko\'pi bilan 100 ta mahsulot bo\'lishi mumkin';

  @override
  String get errorProductUnavailable => 'Bu mahsulot hozir sotuvda yo\'q';

  @override
  String get checkoutTitle => 'Buyurtmani rasmiylashtirish';

  @override
  String get checkoutGo => 'Rasmiylashtirish';

  @override
  String get checkoutAddress => 'Yetkazish manzili';

  @override
  String get checkoutNoAddress => 'Hali manzil yo\'q';

  @override
  String get checkoutAddAddress => 'Manzil qo\'shish';

  @override
  String get checkoutPayment => 'To\'lov usuli';

  @override
  String get checkoutOnlineUnavailable =>
      'Hozircha faqat naqd pul bilan to\'lash mumkin';

  @override
  String get checkoutCalculate => 'Hisoblash';

  @override
  String get checkoutCalculating => 'Hisoblanmoqda';

  @override
  String get checkoutConfirm => 'Buyurtmani tasdiqlash';

  @override
  String get checkoutPlacing => 'Buyurtma yuborilmoqda';

  @override
  String get checkoutEstimateExplain =>
      'Narxi taxminiy mahsulotlar bor: yakuniy summa yig\'uvchi ularni sotib olgach aniqlanadi';

  @override
  String checkoutClosedUntil(String time) {
    return 'Hozir ish vaqti emas. Buyurtma $time dan yig\'ila boshlaydi';
  }

  @override
  String checkoutPlaced(String number) {
    return 'Buyurtma №$number qabul qilindi';
  }

  @override
  String get checkoutBackToCatalog => 'Katalogga qaytish';

  @override
  String get checkoutOpenProfile => 'Ismni kiritish';

  @override
  String get checkoutBackToCart => 'Savatga qaytish';

  @override
  String get errorProfileIncomplete =>
      'Buyurtma berish uchun profilga ismingizni kiriting';

  @override
  String get errorAddressIncomplete =>
      'Manzil to\'liq emas: ko\'cha va uyni kiriting';

  @override
  String get errorAddressGone => 'Bu manzil topilmadi. Boshqasini tanlang';

  @override
  String get errorCartEmpty => 'Savat bo\'sh';

  @override
  String get errorCheckoutProductsUnavailable =>
      'Ba\'zi mahsulotlarni hozir buyurtma qilib bo\'lmaydi: savatda ularni olib tashlang yoki miqdorini to\'g\'rilang';

  @override
  String errorMinimumOrder(String minimum, String shortfall) {
    return 'Eng kam buyurtma — $minimum. Yana ${shortfall}lik mahsulot qo\'shing';
  }

  @override
  String get errorMinimumOrderPlain =>
      'Buyurtma summasi eng kam miqdordan past';

  @override
  String get errorPaymentMethodUnavailable =>
      'Bu to\'lov usuli hozir mavjud emas';

  @override
  String get errorCheckoutStale =>
      'Hisob eskirgan edi va yangilandi. Ko\'rib chiqib, qayta tasdiqlang';

  @override
  String get errorOrderInProgress =>
      'Buyurtma hali yuborilmoqda. Biroz kutib, qayta tasdiqlang';

  @override
  String get checkoutUnconfirmed =>
      'Buyurtma qabul qilingani aniqlanmadi. «Buyurtmani tasdiqlash»ni yana bosing — u ikki marta qabul qilinmaydi';

  @override
  String get cartUnconfirmedOrder =>
      'Oxirgi buyurtmangiz qabul qilingani aniqlanmadi';

  @override
  String get cartCheckUnconfirmed => 'Tekshirish';

  @override
  String get errorInProgress =>
      'So\'rov hali bajarilmoqda. Biroz kutib, qayta urinib ko\'ring';

  @override
  String checkoutPlacedCancelled(String number) {
    return 'Buyurtma №$number bekor qilingan';
  }

  @override
  String get myOrders => 'Buyurtmalarim';

  @override
  String get myOrdersEmpty => 'Hali buyurtma yo\'q';

  @override
  String get customerStatusNew => 'Qabul qilindi';

  @override
  String get customerStatusShoppingAssigned => 'Yig\'uvchi tayinlandi';

  @override
  String get customerStatusShopping => 'Yig\'ilmoqda';

  @override
  String get customerStatusFinalPaymentPending => 'To\'lovni kutmoqda';

  @override
  String get customerStatusReadyForDelivery => 'Yetkazishga tayyor';

  @override
  String get customerStatusDeliveryAssigned => 'Kuryer tayinlandi';

  @override
  String get customerStatusOnTheWay => 'Yo\'lda';

  @override
  String get customerStatusCompleted => 'Yetkazildi';

  @override
  String get customerStatusCancelled => 'Bekor qilindi';

  @override
  String get orderEdit => 'O\'zgartirish';

  @override
  String get orderEditTitle => 'Buyurtmani o\'zgartirish';

  @override
  String get orderEditRemoveLine => 'Buyurtmadan olib tashlash';

  @override
  String get orderEditKeepLine => 'Qaytarish';

  @override
  String get orderEditAtLeastOne =>
      'Buyurtmada kamida bitta mahsulot qolishi kerak';

  @override
  String get orderEditSaving => 'Saqlanmoqda';

  @override
  String get orderEditClosed => 'Bu buyurtmani endi o\'zgartirib bo\'lmaydi';

  @override
  String get orderAddProduct => 'Mahsulot qo\'shish';

  @override
  String get orderAddTitle => 'Buyurtmaga qo\'shish';

  @override
  String get orderAddedLine => 'Qo\'shilmoqda, joriy narxda';

  @override
  String get orderAddAlreadyIn =>
      'Bu mahsulot buyurtmada bor, uni o\'zgartirishingiz mumkin';

  @override
  String orderAddFull(int count) {
    return 'Buyurtmada ko\'pi bilan $count ta mahsulot bo\'lishi mumkin';
  }

  @override
  String get orderCancel => 'Buyurtmani bekor qilish';

  @override
  String get orderCancelConfirm => 'Buyurtma bekor qilinsinmi?';

  @override
  String get orderCancelReason => 'Sabab (ixtiyoriy)';

  @override
  String get orderCancelRepeating =>
      'Avvalgi so\'rov javobsiz qoldi: u shu sabab bilan qayta yuboriladi';

  @override
  String get orderCancelKeep => 'Yo\'q, qoldirish';

  @override
  String get orderCancelling => 'Bekor qilinmoqda';

  @override
  String get orderCancellationRequested =>
      'Bekor qilish so\'raldi: operator hal qiladi';

  @override
  String get orderCancellationNeedsReason =>
      'Xarid boshlangan: bekor qilish sababini yozing, operator hal qiladi';

  @override
  String get orderOpen => 'Buyurtmani ochish';

  @override
  String orderLineRemoved(String reason) {
    return 'Olib tashlandi: $reason';
  }

  @override
  String get errorOrderEditingLocked =>
      'Buyurtmani endi o\'zgartirib bo\'lmaydi. Buyurtma yangilandi';

  @override
  String get errorOrderCancellationNotAllowed =>
      'Buyurtmani endi bekor qilib bo\'lmaydi. Buyurtma yangilandi';

  @override
  String get boardColumnPeople => 'Yig\'uvchi va kuryer';

  @override
  String boardCourierNamed(String name) {
    return 'Kuryer: $name';
  }

  @override
  String get boardFilterCourier => 'Kuryer';

  @override
  String get boardAllCouriers => 'Barcha kuryerlar';

  @override
  String get boardFilteredCourier => 'Tanlangan kuryer';

  @override
  String get boardAwaitingCustomerOnly => 'Mijoz javobini kutayotganlar';

  @override
  String boardPendingQuestions(int count) {
    return 'Mijozga $count ta savol';
  }

  @override
  String attentionShowAll(int count) {
    return 'Hammasini ko\'rsatish ($count)';
  }

  @override
  String get attentionShowFewer => 'Kamroq ko\'rsatish';

  @override
  String get orderSectionCouriers => 'Kuryerlar';

  @override
  String get assignCourier => 'Kuryer tayinlash';

  @override
  String get reassignCourier => 'Kuryerni almashtirish';

  @override
  String get assigningCourier => 'Kuryer tayinlanmoqda';

  @override
  String get pickCourierTitle => 'Kuryerni tanlang';

  @override
  String get pickCourierEmpty => 'Faol kuryerlar yo\'q';

  @override
  String courierStarted(String time) {
    return 'Yo\'lga chiqdi: $time';
  }

  @override
  String get courierEndCompleted => 'yetkazildi';

  @override
  String get courierEndReassigned => 'boshqa kuryerga o\'tkazildi';

  @override
  String get courierEndDeliveryFailed => 'yetkazilmadi';

  @override
  String get deliveryFailureNoAnswer => 'Mijoz javob bermadi';

  @override
  String get deliveryFailureRefused => 'Mijoz qabul qilmadi';

  @override
  String get deliveryFailureWrongAddress => 'Manzil noto\'g\'ri';

  @override
  String get deliveryFailureOther => 'Boshqa sabab';

  @override
  String staffBlockCurrentOrders(int count) {
    return 'Hozir xodimda $count ta buyurtma bor. Boshlangan yig\'ish yoki yo\'ldagi yetkazish boshqa xodimga o\'tmaydi.';
  }

  @override
  String get courierAssignmentsNone => 'Kuryer hali tayinlanmagan';

  @override
  String historyCourierAssignedTo(String name) {
    return 'Kuryer: $name';
  }

  @override
  String historyCourierReassignedTo(String previous, String name) {
    return 'Kuryer: $previous → $name';
  }

  @override
  String get staffBlockOrdersLoading =>
      'Xodimdagi buyurtmalar soni yuklanmoqda…';

  @override
  String get staffBlockOrdersUnknown =>
      'Xodimdagi buyurtmalar sonini bilib bo\'lmadi. Boshlangan yig\'ish yoki yo\'ldagi yetkazish boshqa xodimga o\'tmaydi.';

  @override
  String get orderSectionApprovals => 'Mijozga savollar';

  @override
  String get orderSectionCancellationRequests => 'Bekor qilish so\'rovlari';

  @override
  String get orderSectionPayment => 'To\'lov';

  @override
  String itemBought(String quantity) {
    return 'Sotib olindi: $quantity';
  }

  @override
  String itemBilled(String quantity) {
    return 'Hisobga: $quantity';
  }

  @override
  String itemPricePaid(String price) {
    return 'Sotib olish narxi: $price';
  }

  @override
  String itemBilledPrice(String price) {
    return 'Mijozga narx: $price';
  }

  @override
  String itemReplacedWith(String name) {
    return 'O\'rniga: $name';
  }

  @override
  String get replacementAutomatic => 'avtomatik';

  @override
  String get replacementApproved => 'mijoz rozi bo\'ldi';

  @override
  String get approvalsNone => 'Mijozga savol berilmagan';

  @override
  String get approvalTypePrice => 'Narx chegaradan yuqori';

  @override
  String get approvalTypeSubstitution => 'Almashtirish';

  @override
  String get approvalTypeReducedQuantity => 'Kamroq miqdor';

  @override
  String get approvalStatusPending => 'Javob kutilmoqda';

  @override
  String get approvalStatusApproved => 'Mijoz rozi bo\'ldi';

  @override
  String get approvalStatusRejected => 'Mijoz rad etdi';

  @override
  String get approvalStatusExpired => 'Muddati o\'tdi';

  @override
  String get approvalStatusCancelled => 'Yopildi';

  @override
  String approvalProposedPrice(String price, String paid) {
    return 'Taklif: $price, sotib olish narxi $paid';
  }

  @override
  String approvalProposedQuantity(String quantity) {
    return 'Taklif: $quantity';
  }

  @override
  String approvalReplacement(String name) {
    return 'O\'rniga: $name';
  }

  @override
  String approvalAskedBy(String name, String time) {
    return '$name so\'radi, $time';
  }

  @override
  String approvalTimers(String attention, String expires) {
    return 'Diqqat: $attention · Muddat: $expires';
  }

  @override
  String approvalResolvedBy(String name, String time) {
    return 'Hal qildi: $name, $time';
  }

  @override
  String approvalClosedAt(String time) {
    return 'Yopildi: $time';
  }

  @override
  String get approvalLineRemoved => 'Mahsulot buyurtmadan olib tashlandi';

  @override
  String get removeExpiredLine => 'Mahsulotni olib tashlash';

  @override
  String removeExpiredTitle(String name) {
    return '«$name»ni olib tashlaysizmi?';
  }

  @override
  String get removeExpiredExplained =>
      'Mijoz o\'z vaqtida javob bermadi. Mahsulot buyurtmadan olib tashlanadi; sotib olinadigan boshqa narsa qolmasa, buyurtma bekor qilinadi.';

  @override
  String get cancellationRequestsNone => 'Bekor qilish so\'rovi bo\'lmagan';

  @override
  String get requestStatusPending => 'Qaror kutilmoqda';

  @override
  String get requestStatusApproved => 'Tasdiqlandi';

  @override
  String get requestStatusRejected => 'Rad etildi';

  @override
  String get requestStatusClosed => 'Yopildi';

  @override
  String get requestOriginCustomer => 'Mijozdan';

  @override
  String get requestOriginStaff => 'Xodimdan';

  @override
  String requestReason(String reason) {
    return 'Sabab: $reason';
  }

  @override
  String requestFiledBy(String name, String time) {
    return '$name, $time';
  }

  @override
  String requestDecidedBy(String name, String time) {
    return 'Qaror: $name, $time';
  }

  @override
  String requestClosedAt(String time) {
    return 'Yopildi: $time';
  }

  @override
  String get approveRequest => 'Bekor qilishni tasdiqlash';

  @override
  String get rejectRequest => 'Rad etish';

  @override
  String get approveRequestTitle => 'Buyurtmani bekor qilasizmi?';

  @override
  String get approveRequestExplained =>
      'Buyurtma bekor qilinadi: joriy tayinlov tugaydi, ochiq mahsulotlar olib tashlanadi, sotib olingan narsa qoladi va hech narsa to\'lanmaydi.';

  @override
  String get rejectRequestTitle => 'So\'rovni rad etasizmi?';

  @override
  String get rejectRequestExplained => 'Buyurtma davom etadi.';

  @override
  String get cancelFailedDelivery => 'Buyurtmani bekor qilish';

  @override
  String get cancelFailedDeliveryTitle => 'Buyurtmani bekor qilasizmi?';

  @override
  String get cancelFailedDeliveryExplained =>
      'Buyurtma «yetkazib bo\'lmadi» sababi bilan bekor qilinadi.';

  @override
  String get actionNote => 'Izoh (ixtiyoriy)';

  @override
  String get paymentNone => 'To\'lov hali qayd etilmagan';

  @override
  String get paymentStatusUnpaid => 'To\'lanmagan';

  @override
  String get paymentStatusPending => 'Kutilmoqda';

  @override
  String get paymentStatusPaid => 'To\'langan';

  @override
  String get paymentStatusCancelled => 'Bekor qilingan';

  @override
  String paymentAmount(String amount) {
    return 'Summa: $amount';
  }

  @override
  String paymentPaidAt(String time) {
    return 'To\'langan vaqti: $time';
  }

  @override
  String paymentRecordedBy(String name) {
    return 'Qabul qildi: $name';
  }

  @override
  String get correctPrice => 'Narxni tuzatish';

  @override
  String correctPriceTitle(String name) {
    return 'Narxni tuzatish: $name';
  }

  @override
  String get correctPriceNew => 'Yangi sotib olish narxi, so\'m';

  @override
  String get correctPriceReason => 'Sabab';

  @override
  String errorPriceAboveCeiling(String ceiling) {
    return 'Mijozga narx chegaradan oshadi. Sotib olish narxi mijozga ko\'pi bilan $ceiling bo\'ladigan qilib kiriting.';
  }

  @override
  String get errorPriceAboveCeilingPlain => 'Mijozga narx chegaradan oshadi.';

  @override
  String historyPriceCorrectedDetails(
    String name,
    String oldPaid,
    String newPaid,
    String oldBilled,
    String newBilled,
  ) {
    return '$name: sotib olish narxi $oldPaid → $newPaid, mijozga $oldBilled → $newBilled';
  }

  @override
  String get errorApprovalNotExpired => 'Savolning muddati hali o\'tmagan.';

  @override
  String get errorApprovalAlreadyResolved => 'Savol allaqachon hal qilingan.';

  @override
  String get errorRequestAlreadyDecided =>
      'So\'rov bo\'yicha qaror allaqachon qabul qilingan.';

  @override
  String get errorCancellationAlreadyPending =>
      'Bekor qilish so\'rovi kutilmoqda — avval u bo\'yicha qaror qabul qiling.';

  @override
  String get errorPriceCorrectionLocked =>
      'Narxni endi tuzatib bo\'lmaydi: buyurtma yo\'lda, yakunlangan, bekor qilingan yoki onlayn to\'lanadi.';

  @override
  String get errorPriceCorrectionNotApplicable =>
      'Bu mahsulot narxini tuzatib bo\'lmaydi.';

  @override
  String get staffMenu => 'Menyu';

  @override
  String get shopperOrdersEmpty =>
      'Hozircha sizga buyurtma tayinlanmagan. Tayinlansa, shu yerda paydo bo\'ladi.';

  @override
  String shopperOpenLines(int open, int total) {
    return 'Qolgan mahsulotlar: $open / $total';
  }

  @override
  String get shopperNotAccepted => 'Yangi buyurtma — qabul qiling';

  @override
  String shopperAssignedAt(String time) {
    return 'Tayinlandi: $time';
  }

  @override
  String shopperAcceptedAt(String time) {
    return 'Qabul qilindi: $time';
  }

  @override
  String shopperStartedAt(String time) {
    return 'Yig\'ish boshlandi: $time';
  }

  @override
  String get shopperAccept => 'Qabul qilish';

  @override
  String get shopperStart => 'Yig\'ishni boshlash';

  @override
  String callCustomer(String phone) {
    return 'Mijozga qo\'ng\'iroq: $phone';
  }

  @override
  String callFailed(String phone) {
    return 'Qo\'ng\'iroq ilovasi ochilmadi. Raqamni qo\'lda tering: $phone';
  }

  @override
  String shopperLineCap(String quantity) {
    return 'Mijoz rozi bo\'lgan miqdor: $quantity';
  }

  @override
  String shopperPriceLimit(String price) {
    return 'So\'ramasdan ko\'pi bilan: $price';
  }

  @override
  String shopperQuestion(String type, String time) {
    return 'Mijoz javobi kutilmoqda ($type), $time gacha';
  }

  @override
  String get shopperPageEmpty =>
      'Bu sahifada buyurtma qolmadi. Oldingi sahifaga o\'ting.';

  @override
  String get lineBuy => 'Sotib olish';

  @override
  String get lineReplace => 'Almashtirish';

  @override
  String get lineUnavailable => 'Topilmadi';

  @override
  String purchaseTitle(String name) {
    return 'Sotib olish: $name';
  }

  @override
  String get purchaseQuantity => 'Sotib olingan miqdor';

  @override
  String get purchasePrice => 'Birlik narxi (to\'langan)';

  @override
  String get purchasePriceOptional =>
      'Narxi belgilangan mahsulot: narx ixtiyoriy';

  @override
  String get purchaseSave => 'Sotib oldim';

  @override
  String get purchaseAgain => 'Qayta yuborish';

  @override
  String get purchaseUnconfirmed =>
      'Oxirgi xaridga javob kelmadi — xuddi shu xarid qayta yuboriladi.';

  @override
  String get purchaseAboveBound =>
      'Bu narx mijozdan so\'ramasdan to\'lash mumkin bo\'lganidan yuqori. Mijozdan so\'raysizmi?';

  @override
  String purchaseBelowQuantity(String quantity) {
    return 'Mijozga $quantity kerak. Shuncha sotib oling yoki mijozdan kamroq miqdorga roziligini so\'rang.';
  }

  @override
  String get askNote => 'Mijozga izoh (ixtiyoriy)';

  @override
  String get askPrice => 'Mijozdan narx haqida so\'rash';

  @override
  String get askQuantity => 'Mijozdan miqdor haqida so\'rash';

  @override
  String get typoTitle => 'Narxni tekshiring';

  @override
  String typoExplained(String price, String market) {
    return 'Siz $price kiritdingiz, bozor narxi esa $market. To\'g\'rimi?';
  }

  @override
  String get typoConfirm => 'Ha, to\'g\'ri';

  @override
  String get typoCancel => 'Tuzataman';

  @override
  String unavailableTitle(String name) {
    return '«$name» topilmadimi?';
  }

  @override
  String get unavailableExplained =>
      'Mahsulot buyurtmadan olib tashlanadi. Sotib olinadigan boshqa narsa qolmasa, buyurtma bekor qilinadi.';

  @override
  String get unavailableConfirm => 'Ha, topilmadi';

  @override
  String replaceTitle(String name) {
    return '«$name» o\'rniga';
  }

  @override
  String get replaceSearchHint => 'Mahsulot nomi';

  @override
  String get replaceNone => 'Mos mahsulot topilmadi';

  @override
  String substituteTitle(String name) {
    return 'O\'rniga olish: $name';
  }

  @override
  String get substituteSave => 'Taklif qilish';

  @override
  String get completeShopping => 'Yig\'ishni yakunlash';

  @override
  String get completeTitle => 'Yig\'ish yakunlansinmi?';

  @override
  String get completeExplained =>
      'Yakunlangach, buyurtma ro\'yxatingizdan chiqadi va uni yetkazishga tayyorlanadi.';

  @override
  String get completeUnconfirmed =>
      'Oxirgi yakunlashga javob kelmadi — qayta yuboriladi.';

  @override
  String completeIncomplete(String names) {
    return 'Hali hal qilinmagan: $names';
  }

  @override
  String doneTitle(String number) {
    return 'Buyurtma №$number yig\'ildi';
  }

  @override
  String doneLabel(String number) {
    return 'Paketga $number raqamini yozing va uni topshirish joyiga olib boring.';
  }

  @override
  String get doneBack => 'Buyurtmalarimga';

  @override
  String get errorShoppingNotActive =>
      'Bu buyurtmani hozir yig\'ib bo\'lmaydi.';

  @override
  String get errorItemAlreadyResolved => 'Bu mahsulot allaqachon hal qilingan.';

  @override
  String get errorCustomerApprovalRequired =>
      'Buning uchun mijozning roziligi kerak.';

  @override
  String get errorApprovalNotNeeded =>
      'Bu narx uchun mijozdan so\'rash shart emas — sotib olavering.';

  @override
  String get errorSubstitutionNotAllowed =>
      'Mijoz bu mahsulotni almashtirishga rozi emas.';

  @override
  String get errorShoppingIncomplete => 'Hali hal qilinmagan mahsulotlar bor.';
}
