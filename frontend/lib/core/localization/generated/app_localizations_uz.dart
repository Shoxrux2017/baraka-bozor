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
  String get adminHomeIntro => 'Bo\'limni tanlang';

  @override
  String get adminSectionHome => 'Asosiy';

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
      'Yakuniy narx do\'kondagi chek bo\'yicha aniqlanadi. Narx belgilangan chegaradan oshsa, sizdan rozilik so\'raymiz.';

  @override
  String get catalogLoadMore => 'Yana yuklash';
}
