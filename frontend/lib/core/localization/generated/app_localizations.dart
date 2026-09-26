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

  /// No description provided for @settingsNoChanges.
  ///
  /// In uz, this message translates to:
  /// **'O\'zgarish yo\'q'**
  String get settingsNoChanges;

  /// No description provided for @settingsSaving.
  ///
  /// In uz, this message translates to:
  /// **'Saqlanmoqda'**
  String get settingsSaving;

  /// No description provided for @settingsTashkentTimeHint.
  ///
  /// In uz, this message translates to:
  /// **'Toshkent vaqti bilan'**
  String get settingsTashkentTimeHint;

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

  /// No description provided for @adminSectionCategories.
  ///
  /// In uz, this message translates to:
  /// **'Kategoriyalar'**
  String get adminSectionCategories;

  /// No description provided for @adminSectionProducts.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlar'**
  String get adminSectionProducts;

  /// No description provided for @catalogNameUz.
  ///
  /// In uz, this message translates to:
  /// **'Nomi (o\'zbekcha)'**
  String get catalogNameUz;

  /// No description provided for @catalogNameRu.
  ///
  /// In uz, this message translates to:
  /// **'Nomi (ruscha)'**
  String get catalogNameRu;

  /// No description provided for @catalogDescriptionUz.
  ///
  /// In uz, this message translates to:
  /// **'Tavsif (o\'zbekcha)'**
  String get catalogDescriptionUz;

  /// No description provided for @catalogDescriptionRu.
  ///
  /// In uz, this message translates to:
  /// **'Tavsif (ruscha)'**
  String get catalogDescriptionRu;

  /// No description provided for @catalogSortOrder.
  ///
  /// In uz, this message translates to:
  /// **'Tartib raqami'**
  String get catalogSortOrder;

  /// No description provided for @catalogSortOrderHint.
  ///
  /// In uz, this message translates to:
  /// **'Kichigi ro\'yxatda yuqoriroq turadi'**
  String get catalogSortOrderHint;

  /// No description provided for @catalogShownToCustomers.
  ///
  /// In uz, this message translates to:
  /// **'Mijozlarga ko\'rsatilsin'**
  String get catalogShownToCustomers;

  /// No description provided for @catalogIncludeArchived.
  ///
  /// In uz, this message translates to:
  /// **'Arxivdagilar ham'**
  String get catalogIncludeArchived;

  /// No description provided for @catalogStateActive.
  ///
  /// In uz, this message translates to:
  /// **'Ko\'rsatilmoqda'**
  String get catalogStateActive;

  /// No description provided for @catalogStateHidden.
  ///
  /// In uz, this message translates to:
  /// **'Yashirilgan'**
  String get catalogStateHidden;

  /// No description provided for @catalogStateArchived.
  ///
  /// In uz, this message translates to:
  /// **'Arxivda'**
  String get catalogStateArchived;

  /// No description provided for @catalogEdit.
  ///
  /// In uz, this message translates to:
  /// **'Tahrirlash'**
  String get catalogEdit;

  /// No description provided for @catalogArchive.
  ///
  /// In uz, this message translates to:
  /// **'Arxivlash'**
  String get catalogArchive;

  /// No description provided for @catalogRestore.
  ///
  /// In uz, this message translates to:
  /// **'Arxivdan qaytarish'**
  String get catalogRestore;

  /// No description provided for @catalogArchivedNote.
  ///
  /// In uz, this message translates to:
  /// **'Arxivdagi yozuv mijozlarga ko\'rinmaydi. Qaytarish uchun ro\'yxatdagi amaldan foydalaning'**
  String get catalogArchivedNote;

  /// No description provided for @catalogEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hech narsa topilmadi'**
  String get catalogEmpty;

  /// No description provided for @catalogPage.
  ///
  /// In uz, this message translates to:
  /// **'{page}-sahifa, jami {last}'**
  String catalogPage(int page, int last);

  /// No description provided for @catalogPreviousPage.
  ///
  /// In uz, this message translates to:
  /// **'Oldingi sahifa'**
  String get catalogPreviousPage;

  /// No description provided for @catalogNextPage.
  ///
  /// In uz, this message translates to:
  /// **'Keyingi sahifa'**
  String get catalogNextPage;

  /// No description provided for @categoryNew.
  ///
  /// In uz, this message translates to:
  /// **'Yangi kategoriya'**
  String get categoryNew;

  /// No description provided for @categoryEditTitle.
  ///
  /// In uz, this message translates to:
  /// **'Kategoriyani tahrirlash'**
  String get categoryEditTitle;

  /// No description provided for @categorySaved.
  ///
  /// In uz, this message translates to:
  /// **'Kategoriya saqlandi'**
  String get categorySaved;

  /// No description provided for @productNew.
  ///
  /// In uz, this message translates to:
  /// **'Yangi mahsulot'**
  String get productNew;

  /// No description provided for @productEditTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotni tahrirlash'**
  String get productEditTitle;

  /// No description provided for @productSaved.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot saqlandi'**
  String get productSaved;

  /// No description provided for @productCategory.
  ///
  /// In uz, this message translates to:
  /// **'Kategoriya'**
  String get productCategory;

  /// No description provided for @productAllCategories.
  ///
  /// In uz, this message translates to:
  /// **'Barcha kategoriyalar'**
  String get productAllCategories;

  /// No description provided for @productUnit.
  ///
  /// In uz, this message translates to:
  /// **'O\'lchov birligi'**
  String get productUnit;

  /// No description provided for @productPriceMode.
  ///
  /// In uz, this message translates to:
  /// **'Narx turi'**
  String get productPriceMode;

  /// No description provided for @productMarketPrice.
  ///
  /// In uz, this message translates to:
  /// **'Bozor narxi'**
  String get productMarketPrice;

  /// No description provided for @productCustomerPrice.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz uchun narx: {price}'**
  String productCustomerPrice(String price);

  /// No description provided for @productSearch.
  ///
  /// In uz, this message translates to:
  /// **'Nomi bo\'yicha qidirish'**
  String get productSearch;

  /// No description provided for @productBackToList.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlar ro\'yxati'**
  String get productBackToList;

  /// No description provided for @productImage.
  ///
  /// In uz, this message translates to:
  /// **'Rasm'**
  String get productImage;

  /// No description provided for @productNoImage.
  ///
  /// In uz, this message translates to:
  /// **'Rasm yo\'q'**
  String get productNoImage;

  /// No description provided for @productChooseImage.
  ///
  /// In uz, this message translates to:
  /// **'Rasm tanlash'**
  String get productChooseImage;

  /// No description provided for @productUploadImage.
  ///
  /// In uz, this message translates to:
  /// **'Yuklash'**
  String get productUploadImage;

  /// No description provided for @productRemoveImage.
  ///
  /// In uz, this message translates to:
  /// **'Rasmni o\'chirish'**
  String get productRemoveImage;

  /// No description provided for @productRemoveImageConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot rasmi o\'chirilsinmi?'**
  String get productRemoveImageConfirm;

  /// No description provided for @productImageRules.
  ///
  /// In uz, this message translates to:
  /// **'JPEG, PNG yoki WebP, ko\'pi bilan 5 MB'**
  String get productImageRules;

  /// No description provided for @productImageTooLarge.
  ///
  /// In uz, this message translates to:
  /// **'Rasm 5 MB dan katta'**
  String get productImageTooLarge;

  /// No description provided for @productImageWrongType.
  ///
  /// In uz, this message translates to:
  /// **'Faqat JPEG, PNG yoki WebP rasm'**
  String get productImageWrongType;

  /// No description provided for @productImageUnreadable.
  ///
  /// In uz, this message translates to:
  /// **'Faylni o\'qib bo\'lmadi. Boshqa faylni tanlang'**
  String get productImageUnreadable;

  /// No description provided for @productImageAfterSave.
  ///
  /// In uz, this message translates to:
  /// **'Rasmni mahsulot saqlangandan keyin qo\'shish mumkin'**
  String get productImageAfterSave;

  /// No description provided for @priceModeFixed.
  ///
  /// In uz, this message translates to:
  /// **'Aniq narx'**
  String get priceModeFixed;

  /// No description provided for @priceModeEstimate.
  ///
  /// In uz, this message translates to:
  /// **'Taxminiy narx'**
  String get priceModeEstimate;

  /// No description provided for @unitKg.
  ///
  /// In uz, this message translates to:
  /// **'kg'**
  String get unitKg;

  /// No description provided for @unitGram.
  ///
  /// In uz, this message translates to:
  /// **'g'**
  String get unitGram;

  /// No description provided for @unitPiece.
  ///
  /// In uz, this message translates to:
  /// **'dona'**
  String get unitPiece;

  /// No description provided for @unitLiter.
  ///
  /// In uz, this message translates to:
  /// **'l'**
  String get unitLiter;

  /// No description provided for @unitPackage.
  ///
  /// In uz, this message translates to:
  /// **'qadoq'**
  String get unitPackage;

  /// No description provided for @unitBox.
  ///
  /// In uz, this message translates to:
  /// **'quti'**
  String get unitBox;

  /// No description provided for @unitBundle.
  ///
  /// In uz, this message translates to:
  /// **'bog\''**
  String get unitBundle;

  /// No description provided for @unitMeter.
  ///
  /// In uz, this message translates to:
  /// **'m'**
  String get unitMeter;

  /// No description provided for @fieldTooLong.
  ///
  /// In uz, this message translates to:
  /// **'Ko\'pi bilan {max} ta belgi'**
  String fieldTooLong(int max);

  /// No description provided for @fieldSortOrder.
  ///
  /// In uz, this message translates to:
  /// **'-100 000 dan 100 000 gacha butun son'**
  String get fieldSortOrder;

  /// No description provided for @fieldMarketPrice.
  ///
  /// In uz, this message translates to:
  /// **'1 dan 1 000 000 000 gacha butun son'**
  String get fieldMarketPrice;

  /// No description provided for @errorBusinessConflict.
  ///
  /// In uz, this message translates to:
  /// **'Ma\'lumot allaqachon o\'zgargan. Joriy holatni tekshirib, qayta urinib ko\'ring'**
  String get errorBusinessConflict;

  /// No description provided for @errorPayloadTooLarge.
  ///
  /// In uz, this message translates to:
  /// **'Fayl juda katta'**
  String get errorPayloadTooLarge;
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
