import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('uz'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In uz, this message translates to:
  /// **'BarakaBozor'**
  String get appTitle;

  /// No description provided for @customerLoginTitle.
  ///
  /// In uz, this message translates to:
  /// **'Kirish'**
  String get customerLoginTitle;

  /// No description provided for @customerLoginIntro.
  ///
  /// In uz, this message translates to:
  /// **'Telefon raqamingizni kiriting, biz sizga kirish kodini yuboramiz'**
  String get customerLoginIntro;

  /// No description provided for @phoneLabel.
  ///
  /// In uz, this message translates to:
  /// **'Telefon raqami'**
  String get phoneLabel;

  /// No description provided for @phoneHint.
  ///
  /// In uz, this message translates to:
  /// **'90 123 45 67'**
  String get phoneHint;

  /// No description provided for @phoneInvalid.
  ///
  /// In uz, this message translates to:
  /// **'Raqamning 9 ta raqamini kiriting'**
  String get phoneInvalid;

  /// No description provided for @continueButton.
  ///
  /// In uz, this message translates to:
  /// **'Davom etish'**
  String get continueButton;

  /// No description provided for @codeSentTelegram.
  ///
  /// In uz, this message translates to:
  /// **'Kod Telegram orqali yuborildi'**
  String get codeSentTelegram;

  /// No description provided for @codeSentSms.
  ///
  /// In uz, this message translates to:
  /// **'Kod SMS orqali yuborildi'**
  String get codeSentSms;

  /// No description provided for @codeSentGeneric.
  ///
  /// In uz, this message translates to:
  /// **'Kod yuborildi'**
  String get codeSentGeneric;

  /// No description provided for @codeLabel.
  ///
  /// In uz, this message translates to:
  /// **'Kirish kodi'**
  String get codeLabel;

  /// No description provided for @codeInvalidFormat.
  ///
  /// In uz, this message translates to:
  /// **'6 ta raqamdan iborat kodni kiriting'**
  String get codeInvalidFormat;

  /// No description provided for @verifyButton.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlash'**
  String get verifyButton;

  /// No description provided for @resendCode.
  ///
  /// In uz, this message translates to:
  /// **'Kodni qayta yuborish'**
  String get resendCode;

  /// No description provided for @resendIn.
  ///
  /// In uz, this message translates to:
  /// **'Qayta yuborish {seconds} soniyadan so\'ng'**
  String resendIn(int seconds);

  /// No description provided for @changePhone.
  ///
  /// In uz, this message translates to:
  /// **'Raqamni o\'zgartirish'**
  String get changePhone;

  /// No description provided for @codeSentToPhone.
  ///
  /// In uz, this message translates to:
  /// **'Kod {phone} raqamiga yuborildi'**
  String codeSentToPhone(String phone);

  /// No description provided for @customerModeIntro.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz rejimiga kirish uchun o\'z raqamingizga yuborilgan kodni kiriting'**
  String get customerModeIntro;

  /// No description provided for @cancelButton.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish'**
  String get cancelButton;

  /// No description provided for @requestCodeButton.
  ///
  /// In uz, this message translates to:
  /// **'Kod so\'rash'**
  String get requestCodeButton;

  /// No description provided for @wrongSurfaceTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bu yerdan kirib bo\'lmaydi'**
  String get wrongSurfaceTitle;

  /// No description provided for @staffLoginTitle.
  ///
  /// In uz, this message translates to:
  /// **'Xodim kirishi'**
  String get staffLoginTitle;

  /// No description provided for @staffLoginLink.
  ///
  /// In uz, this message translates to:
  /// **'Xodim sifatida kirish'**
  String get staffLoginLink;

  /// No description provided for @customerLoginLink.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz sifatida kirish'**
  String get customerLoginLink;

  /// No description provided for @passwordLabel.
  ///
  /// In uz, this message translates to:
  /// **'Parol'**
  String get passwordLabel;

  /// No description provided for @passwordRequired.
  ///
  /// In uz, this message translates to:
  /// **'Parolni kiriting'**
  String get passwordRequired;

  /// No description provided for @loginButton.
  ///
  /// In uz, this message translates to:
  /// **'Kirish'**
  String get loginButton;

  /// No description provided for @changePasswordTitle.
  ///
  /// In uz, this message translates to:
  /// **'Parolni o\'zgartirish'**
  String get changePasswordTitle;

  /// No description provided for @changePasswordRequiredIntro.
  ///
  /// In uz, this message translates to:
  /// **'Davom etishdan oldin vaqtinchalik parolni o\'zingiznikiga almashtiring'**
  String get changePasswordRequiredIntro;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In uz, this message translates to:
  /// **'Joriy parol'**
  String get currentPasswordLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In uz, this message translates to:
  /// **'Yangi parol'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In uz, this message translates to:
  /// **'Yangi parolni takrorlang'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordRuleHint.
  ///
  /// In uz, this message translates to:
  /// **'10 tadan 128 tagacha belgi'**
  String get passwordRuleHint;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In uz, this message translates to:
  /// **'Parollar mos kelmadi'**
  String get passwordsDoNotMatch;

  /// No description provided for @savePasswordButton.
  ///
  /// In uz, this message translates to:
  /// **'Saqlash'**
  String get savePasswordButton;

  /// No description provided for @passwordChanged.
  ///
  /// In uz, this message translates to:
  /// **'Parol o\'zgartirildi'**
  String get passwordChanged;

  /// No description provided for @logoutButton.
  ///
  /// In uz, this message translates to:
  /// **'Chiqish'**
  String get logoutButton;

  /// No description provided for @wrongSurfaceMobile.
  ///
  /// In uz, this message translates to:
  /// **'Bu hisob veb-panelda ishlaydi. Kompyuterdagi brauzer orqali kiring.'**
  String get wrongSurfaceMobile;

  /// No description provided for @wrongSurfaceWeb.
  ///
  /// In uz, this message translates to:
  /// **'Bu hisob mobil ilovada ishlaydi. Telefondagi BarakaBozor ilovasi orqali kiring.'**
  String get wrongSurfaceWeb;

  /// No description provided for @languageLabel.
  ///
  /// In uz, this message translates to:
  /// **'Til'**
  String get languageLabel;

  /// No description provided for @languageUzbek.
  ///
  /// In uz, this message translates to:
  /// **'O\'zbekcha'**
  String get languageUzbek;

  /// No description provided for @languageRussian.
  ///
  /// In uz, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @retryButton.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinish'**
  String get retryButton;

  /// No description provided for @shellCustomer.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz'**
  String get shellCustomer;

  /// No description provided for @shellShopper.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi'**
  String get shellShopper;

  /// No description provided for @shellCourier.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer'**
  String get shellCourier;

  /// No description provided for @shellOperations.
  ///
  /// In uz, this message translates to:
  /// **'Operatsiyalar'**
  String get shellOperations;

  /// No description provided for @shellAdmin.
  ///
  /// In uz, this message translates to:
  /// **'Administrator'**
  String get shellAdmin;

  /// No description provided for @shellManager.
  ///
  /// In uz, this message translates to:
  /// **'Menejer'**
  String get shellManager;

  /// No description provided for @shellPlaceholder.
  ///
  /// In uz, this message translates to:
  /// **'Bu bo\'lim keyingi bosqichda paydo bo\'ladi'**
  String get shellPlaceholder;

  /// No description provided for @customerModeLabel.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz rejimi'**
  String get customerModeLabel;

  /// No description provided for @staffModeLabel.
  ///
  /// In uz, this message translates to:
  /// **'Xodim rejimi'**
  String get staffModeLabel;

  /// No description provided for @switchToCustomer.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz sifatida davom etish'**
  String get switchToCustomer;

  /// No description provided for @switchToStaff.
  ///
  /// In uz, this message translates to:
  /// **'Xodim rejimiga qaytish'**
  String get switchToStaff;

  /// No description provided for @sessionUnreachableTitle.
  ///
  /// In uz, this message translates to:
  /// **'Server bilan aloqa yo\'q'**
  String get sessionUnreachableTitle;

  /// No description provided for @sessionUnreachableBody.
  ///
  /// In uz, this message translates to:
  /// **'Internet aloqasini tekshiring va qayta urinib ko\'ring'**
  String get sessionUnreachableBody;

  /// No description provided for @errorAuthenticationRequired.
  ///
  /// In uz, this message translates to:
  /// **'Qaytadan kiring'**
  String get errorAuthenticationRequired;

  /// No description provided for @errorAccountBlocked.
  ///
  /// In uz, this message translates to:
  /// **'Bu hisob bloklangan'**
  String get errorAccountBlocked;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In uz, this message translates to:
  /// **'Telefon raqami yoki parol noto\'g\'ri'**
  String get errorInvalidCredentials;

  /// No description provided for @errorCodeInvalid.
  ///
  /// In uz, this message translates to:
  /// **'Kod noto\'g\'ri'**
  String get errorCodeInvalid;

  /// No description provided for @errorCodeExpired.
  ///
  /// In uz, this message translates to:
  /// **'Kod muddati tugadi. Yangi kod so\'rang'**
  String get errorCodeExpired;

  /// No description provided for @errorCodeAttemptsExhausted.
  ///
  /// In uz, this message translates to:
  /// **'Urinishlar soni tugadi. Yangi kod so\'rang'**
  String get errorCodeAttemptsExhausted;

  /// No description provided for @errorCodeResendTooSoon.
  ///
  /// In uz, this message translates to:
  /// **'Kodni qayta yuborishdan oldin biroz kuting'**
  String get errorCodeResendTooSoon;

  /// No description provided for @errorRateLimited.
  ///
  /// In uz, this message translates to:
  /// **'Urinishlar juda ko\'p. Biroz kutib turing'**
  String get errorRateLimited;

  /// No description provided for @errorProviderUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Xizmat vaqtincha ishlamayapti. Keyinroq urinib ko\'ring'**
  String get errorProviderUnavailable;

  /// No description provided for @errorServiceUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Texnik ishlar olib borilmoqda. Keyinroq urinib ko\'ring'**
  String get errorServiceUnavailable;

  /// No description provided for @errorServerError.
  ///
  /// In uz, this message translates to:
  /// **'Kutilmagan xatolik. Keyinroq urinib ko\'ring'**
  String get errorServerError;

  /// No description provided for @errorNetwork.
  ///
  /// In uz, this message translates to:
  /// **'Internet aloqasi yo\'q'**
  String get errorNetwork;

  /// No description provided for @errorValidationFailed.
  ///
  /// In uz, this message translates to:
  /// **'Kiritilgan ma\'lumotlarni tekshiring'**
  String get errorValidationFailed;

  /// No description provided for @errorForbidden.
  ///
  /// In uz, this message translates to:
  /// **'Bu amalga ruxsat yo\'q'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In uz, this message translates to:
  /// **'Topilmadi'**
  String get errorNotFound;

  /// No description provided for @errorPasswordChangeRequired.
  ///
  /// In uz, this message translates to:
  /// **'Avval parolni o\'zgartiring'**
  String get errorPasswordChangeRequired;

  /// No description provided for @errorUnknown.
  ///
  /// In uz, this message translates to:
  /// **'Xatolik yuz berdi. Qayta urinib ko\'ring'**
  String get errorUnknown;

  /// No description provided for @adminHomeIntro.
  ///
  /// In uz, this message translates to:
  /// **'Bo\'limni tanlang'**
  String get adminHomeIntro;

  /// No description provided for @adminSectionHome.
  ///
  /// In uz, this message translates to:
  /// **'Asosiy'**
  String get adminSectionHome;

  /// No description provided for @adminSectionSettings.
  ///
  /// In uz, this message translates to:
  /// **'Sozlamalar'**
  String get adminSectionSettings;

  /// No description provided for @saveButton.
  ///
  /// In uz, this message translates to:
  /// **'Saqlash'**
  String get saveButton;

  /// No description provided for @settingsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Biznes sozlamalari'**
  String get settingsTitle;

  /// No description provided for @settingsPricingSection.
  ///
  /// In uz, this message translates to:
  /// **'Narxlar va yig\'imlar'**
  String get settingsPricingSection;

  /// No description provided for @settingsMarkup.
  ///
  /// In uz, this message translates to:
  /// **'Ustama, %'**
  String get settingsMarkup;

  /// No description provided for @settingsServiceFeeMode.
  ///
  /// In uz, this message translates to:
  /// **'Xizmat haqi'**
  String get settingsServiceFeeMode;

  /// No description provided for @settingsServiceFeeFixed.
  ///
  /// In uz, this message translates to:
  /// **'Belgilangan summa'**
  String get settingsServiceFeeFixed;

  /// No description provided for @settingsServiceFeePercentage.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmaning foizi'**
  String get settingsServiceFeePercentage;

  /// No description provided for @settingsServiceFeeAmount.
  ///
  /// In uz, this message translates to:
  /// **'Xizmat haqi summasi'**
  String get settingsServiceFeeAmount;

  /// No description provided for @settingsServiceFeePercent.
  ///
  /// In uz, this message translates to:
  /// **'Xizmat haqi, %'**
  String get settingsServiceFeePercent;

  /// No description provided for @settingsDeliveryFee.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazib berish narxi'**
  String get settingsDeliveryFee;

  /// No description provided for @settingsMinimumOrder.
  ///
  /// In uz, this message translates to:
  /// **'Eng kam buyurtma summasi'**
  String get settingsMinimumOrder;

  /// No description provided for @settingsPriceTolerance.
  ///
  /// In uz, this message translates to:
  /// **'Narx oshishi chegarasi, %'**
  String get settingsPriceTolerance;

  /// No description provided for @settingsPriceToleranceHint.
  ///
  /// In uz, this message translates to:
  /// **'Narx bundan ko\'proq oshsa, mijozning roziligi so\'raladi'**
  String get settingsPriceToleranceHint;

  /// No description provided for @settingsOptionalHint.
  ///
  /// In uz, this message translates to:
  /// **'Bo\'sh qoldirilsa, o\'rnatilmagan'**
  String get settingsOptionalHint;

  /// No description provided for @settingsHoursSection.
  ///
  /// In uz, this message translates to:
  /// **'Ish vaqti'**
  String get settingsHoursSection;

  /// No description provided for @settingsOpensAt.
  ///
  /// In uz, this message translates to:
  /// **'Ochilish vaqti'**
  String get settingsOpensAt;

  /// No description provided for @settingsClosesAt.
  ///
  /// In uz, this message translates to:
  /// **'Yopilish vaqti'**
  String get settingsClosesAt;

  /// No description provided for @settingsAreaSection.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazib berish hududi'**
  String get settingsAreaSection;

  /// No description provided for @settingsCentreLatitude.
  ///
  /// In uz, this message translates to:
  /// **'Markaz kengligi'**
  String get settingsCentreLatitude;

  /// No description provided for @settingsCentreLongitude.
  ///
  /// In uz, this message translates to:
  /// **'Markaz uzunligi'**
  String get settingsCentreLongitude;

  /// No description provided for @settingsRadius.
  ///
  /// In uz, this message translates to:
  /// **'Radius, km'**
  String get settingsRadius;

  /// No description provided for @settingsDeliverySection.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazib berish nazorati'**
  String get settingsDeliverySection;

  /// No description provided for @settingsDelayThreshold.
  ///
  /// In uz, this message translates to:
  /// **'Kechikish chegarasi, daqiqa'**
  String get settingsDelayThreshold;

  /// No description provided for @settingsSaved.
  ///
  /// In uz, this message translates to:
  /// **'Sozlamalar saqlandi'**
  String get settingsSaved;

  /// No description provided for @settingsUpdatedAt.
  ///
  /// In uz, this message translates to:
  /// **'Oxirgi o\'zgarish: {when}'**
  String settingsUpdatedAt(String when);

  /// No description provided for @providersTitle.
  ///
  /// In uz, this message translates to:
  /// **'Onlayn to\'lov'**
  String get providersTitle;

  /// No description provided for @providersIntro.
  ///
  /// In uz, this message translates to:
  /// **'Yoqilgan tizimlar mijozga to\'lov usuli sifatida taklif qilinadi'**
  String get providersIntro;

  /// No description provided for @fieldRequired.
  ///
  /// In uz, this message translates to:
  /// **'Maydonni to\'ldiring'**
  String get fieldRequired;

  /// No description provided for @fieldPercent.
  ///
  /// In uz, this message translates to:
  /// **'0 dan 999.99 gacha son, nuqtadan keyin ko\'pi bilan 2 raqam'**
  String get fieldPercent;

  /// No description provided for @fieldAmount.
  ///
  /// In uz, this message translates to:
  /// **'0 dan 1 000 000 000 gacha butun son'**
  String get fieldAmount;

  /// No description provided for @fieldTime.
  ///
  /// In uz, this message translates to:
  /// **'Vaqtni 09:00 ko\'rinishida kiriting'**
  String get fieldTime;

  /// No description provided for @fieldLatitude.
  ///
  /// In uz, this message translates to:
  /// **'-90 dan 90 gacha, nuqtadan keyin ko\'pi bilan 6 raqam'**
  String get fieldLatitude;

  /// No description provided for @fieldLongitude.
  ///
  /// In uz, this message translates to:
  /// **'-180 dan 180 gacha, nuqtadan keyin ko\'pi bilan 6 raqam'**
  String get fieldLongitude;

  /// No description provided for @fieldRadius.
  ///
  /// In uz, this message translates to:
  /// **'0 dan katta va 9999.99 gacha, nuqtadan keyin ko\'pi bilan 2 raqam'**
  String get fieldRadius;

  /// No description provided for @fieldMinutes.
  ///
  /// In uz, this message translates to:
  /// **'1 dan 1440 gacha butun son'**
  String get fieldMinutes;

  /// No description provided for @fieldPairIncomplete.
  ///
  /// In uz, this message translates to:
  /// **'Ikkala qiymatni kiriting yoki ikkalasini ham bo\'sh qoldiring'**
  String get fieldPairIncomplete;

  /// No description provided for @fieldSameTime.
  ///
  /// In uz, this message translates to:
  /// **'Yopilish vaqti ochilish vaqtidan farq qilishi kerak'**
  String get fieldSameTime;

  /// No description provided for @fieldRejected.
  ///
  /// In uz, this message translates to:
  /// **'Server bu qiymatni qabul qilmadi'**
  String get fieldRejected;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
