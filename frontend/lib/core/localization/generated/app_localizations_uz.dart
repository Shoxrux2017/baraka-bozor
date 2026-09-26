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
  String get phoneHint => '+998 90 123 45 67';

  @override
  String get phoneInvalid =>
      'Raqamni +998 va 9 ta raqam ko\'rinishida kiriting';

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
  String get shellShopper => 'Xaridchi';

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
}
