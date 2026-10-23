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
  /// **'Telefon raqamingizni kiriting — kirish kodini yuboramiz'**
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

  /// No description provided for @codeSentSms.
  ///
  /// In uz, this message translates to:
  /// **'Kod SMS orqali yuborildi'**
  String get codeSentSms;

  /// No description provided for @codeSentOnPhone.
  ///
  /// In uz, this message translates to:
  /// **'Kodni yubordik: {phone}'**
  String codeSentOnPhone(String phone);

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
  /// **'{time} dan so\'ng qayta yuborish'**
  String resendIn(String time);

  /// No description provided for @codeLocked.
  ///
  /// In uz, this message translates to:
  /// **'Kod 3 marta noto\'g\'ri kiritildi. Yangi kodni {time} dan keyin so\'rash mumkin'**
  String codeLocked(String time);

  /// No description provided for @codeLockOver.
  ///
  /// In uz, this message translates to:
  /// **'Yangi kod so\'rang'**
  String get codeLockOver;

  /// No description provided for @changePhone.
  ///
  /// In uz, this message translates to:
  /// **'Raqamni o\'zgartirish'**
  String get changePhone;

  /// No description provided for @codeSentToPhone.
  ///
  /// In uz, this message translates to:
  /// **'Kodni Telegramga yubordik: {phone}'**
  String codeSentToPhone(String phone);

  /// No description provided for @cancelButton.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish'**
  String get cancelButton;

  /// No description provided for @wrongSurfaceTitle.
  ///
  /// In uz, this message translates to:
  /// **'Veb-panelni oching'**
  String get wrongSurfaceTitle;

  /// No description provided for @staffLoginTitle.
  ///
  /// In uz, this message translates to:
  /// **'Xodim kirishi'**
  String get staffLoginTitle;

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
  /// **'Parol o\'ylab toping'**
  String get changePasswordTitle;

  /// No description provided for @changePasswordRequiredIntro.
  ///
  /// In uz, this message translates to:
  /// **'Administrator vaqtinchalik parol berdi. Uni o\'zingiznikiga almashtiring'**
  String get changePasswordRequiredIntro;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In uz, this message translates to:
  /// **'Vaqtinchalik parol'**
  String get currentPasswordLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In uz, this message translates to:
  /// **'Yangi parol'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In uz, this message translates to:
  /// **'Parolni takrorlang'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordRuleHint.
  ///
  /// In uz, this message translates to:
  /// **'Kamida 10 ta belgi'**
  String get passwordRuleHint;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In uz, this message translates to:
  /// **'Parollar mos kelmadi'**
  String get passwordsDoNotMatch;

  /// No description provided for @savePasswordButton.
  ///
  /// In uz, this message translates to:
  /// **'Parolni saqlash'**
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
  /// **'Bu hisob kompyuterdagi brauzerda ishlaydi. BarakaBozor veb-paneli orqali kiring'**
  String get wrongSurfaceMobile;

  /// No description provided for @wrongSurfaceWeb.
  ///
  /// In uz, this message translates to:
  /// **'Bu hisob telefondagi BarakaBozor ilovasida ishlaydi'**
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

  /// No description provided for @panelSectionBoard.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalar'**
  String get panelSectionBoard;

  /// No description provided for @panelMenuLabel.
  ///
  /// In uz, this message translates to:
  /// **'Panel'**
  String get panelMenuLabel;

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

  /// No description provided for @errorCodeLocked.
  ///
  /// In uz, this message translates to:
  /// **'Juda ko\'p noto\'g\'ri urinish. Biroz kuting'**
  String get errorCodeLocked;

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

  /// No description provided for @catalogProductCount.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta mahsulot'**
  String catalogProductCount(int count);

  /// No description provided for @catalogCategoryCount.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta kategoriya'**
  String catalogCategoryCount(int count);

  /// No description provided for @categoryShownHint.
  ///
  /// In uz, this message translates to:
  /// **'Yashirilgan kategoriya mijozlardan barcha mahsulotlarini ham yashiradi'**
  String get categoryShownHint;

  /// No description provided for @categoryArchiveTitle.
  ///
  /// In uz, this message translates to:
  /// **'Kategoriya arxivlansinmi?'**
  String get categoryArchiveTitle;

  /// No description provided for @categoryArchiveExplained.
  ///
  /// In uz, this message translates to:
  /// **'Kategoriya va uning barcha mahsulotlari mijozlarga ko\'rinmay qoladi. Mahsulotlarning o\'zi o\'zgarmaydi: kategoriyani qaytarsangiz, ular yana chiqadi. Kategoriya arxivda ekan, unga yangi mahsulot qo\'shib bo\'lmaydi.'**
  String get categoryArchiveExplained;

  /// No description provided for @catalogColumnProduct.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot'**
  String get catalogColumnProduct;

  /// No description provided for @catalogColumnCustomerPrice.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz uchun'**
  String get catalogColumnCustomerPrice;

  /// No description provided for @catalogColumnShown.
  ///
  /// In uz, this message translates to:
  /// **'Ko\'rinishi'**
  String get catalogColumnShown;

  /// No description provided for @catalogForCustomer.
  ///
  /// In uz, this message translates to:
  /// **'mijozga {price}'**
  String catalogForCustomer(String price);

  /// No description provided for @catalogCategoryHiddenLine.
  ///
  /// In uz, this message translates to:
  /// **'Kategoriya yashirilgan — mijozlar ko\'rmaydi'**
  String get catalogCategoryHiddenLine;

  /// No description provided for @catalogCategoryArchivedLine.
  ///
  /// In uz, this message translates to:
  /// **'Kategoriya arxivda — mijozlar ko\'rmaydi'**
  String get catalogCategoryArchivedLine;

  /// No description provided for @catalogEmptyHint.
  ///
  /// In uz, this message translates to:
  /// **'Nomini tekshiring yoki «Barcha kategoriyalar»ni tanlang.'**
  String get catalogEmptyHint;

  /// No description provided for @productArchiveTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot arxivlansinmi?'**
  String get productArchiveTitle;

  /// No description provided for @productArchiveExplained.
  ///
  /// In uz, this message translates to:
  /// **'Mijozlar mahsulotni ko\'rmay qoladi, savatlarda u mavjud bo\'lmaydi. U bor buyurtmalar o\'zgarmaydi. Uni «Arxivdagilar ham» ro\'yxatidan qaytarish mumkin.'**
  String get productArchiveExplained;

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

  /// No description provided for @categoryImage.
  ///
  /// In uz, this message translates to:
  /// **'Rasm'**
  String get categoryImage;

  /// No description provided for @categoryImageAfterSave.
  ///
  /// In uz, this message translates to:
  /// **'Rasmni saqlagandan keyin qo\'shish mumkin'**
  String get categoryImageAfterSave;

  /// No description provided for @categoryRemoveImageConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Kategoriya rasmi o\'chirilsinmi?'**
  String get categoryRemoveImageConfirm;

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

  /// No description provided for @productFeatured.
  ///
  /// In uz, this message translates to:
  /// **'Tavsiya etamiz bo\'limida ko\'rsatish'**
  String get productFeatured;

  /// No description provided for @productFeaturedHint.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot bosh sahifadagi «Tavsiya etamiz» qatorida chiqadi'**
  String get productFeaturedHint;

  /// No description provided for @productFeaturedBadge.
  ///
  /// In uz, this message translates to:
  /// **'Tavsiya'**
  String get productFeaturedBadge;

  /// No description provided for @productMarketPrice.
  ///
  /// In uz, this message translates to:
  /// **'Bozor narxi'**
  String get productMarketPrice;

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

  /// No description provided for @productImagePicked.
  ///
  /// In uz, this message translates to:
  /// **'Yangi rasm · yuklanmagan'**
  String get productImagePicked;

  /// No description provided for @productRemoveImageExplained.
  ///
  /// In uz, this message translates to:
  /// **'Yangisini yuklamaguningizcha mijozlar mahsulotni rasmsiz ko\'radi.'**
  String get productRemoveImageExplained;

  /// No description provided for @categoryRemoveImageExplained.
  ///
  /// In uz, this message translates to:
  /// **'Yangi rasm yuklamaguningizcha mijozlar nomning birinchi harfini ko\'radi.'**
  String get categoryRemoveImageExplained;

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

  /// No description provided for @productSectionMain.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot'**
  String get productSectionMain;

  /// No description provided for @productSectionPrice.
  ///
  /// In uz, this message translates to:
  /// **'Narx'**
  String get productSectionPrice;

  /// No description provided for @productSectionShown.
  ///
  /// In uz, this message translates to:
  /// **'Ko\'rinishi'**
  String get productSectionShown;

  /// No description provided for @productMarkupNote.
  ///
  /// In uz, this message translates to:
  /// **'Ustama barcha mahsulotlar uchun bitta — u «Sozlamalar»da.'**
  String get productMarkupNote;

  /// No description provided for @productPriceHint.
  ///
  /// In uz, this message translates to:
  /// **'Butun son, 1 {unit} uchun'**
  String productPriceHint(String unit);

  /// No description provided for @productCustomerPriceTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz uchun narx'**
  String get productCustomerPriceTitle;

  /// No description provided for @productCustomerPriceBasis.
  ///
  /// In uz, this message translates to:
  /// **'Saqlangan {price} narxi bo\'yicha. «Saqlash»dan keyin qayta hisoblanadi.'**
  String productCustomerPriceBasis(String price);

  /// No description provided for @productCustomerPriceLater.
  ///
  /// In uz, this message translates to:
  /// **'Saqlangandan keyin chiqadi'**
  String get productCustomerPriceLater;

  /// No description provided for @catalogOptional.
  ///
  /// In uz, this message translates to:
  /// **'Ixtiyoriy'**
  String get catalogOptional;

  /// No description provided for @productShownHint.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotni arxivlamasdan yashirish uchun o\'chiring'**
  String get productShownHint;

  /// No description provided for @productCategoryHiddenNote.
  ///
  /// In uz, this message translates to:
  /// **'«{name}» kategoriyasi yashirilgan, shu sababli mijozlar bu mahsulotni ham ko\'rmaydi. Uni «Kategoriyalar» bo\'limida yoqish mumkin.'**
  String productCategoryHiddenNote(String name);

  /// No description provided for @productCategoryArchivedNote.
  ///
  /// In uz, this message translates to:
  /// **'«{name}» kategoriyasi arxivda, shu sababli mijozlar bu mahsulotni ham ko\'rmaydi. Uni «Kategoriyalar» bo\'limida qaytarish mumkin.'**
  String productCategoryArchivedNote(String name);

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

  /// No description provided for @adminSectionStaff.
  ///
  /// In uz, this message translates to:
  /// **'Xodimlar'**
  String get adminSectionStaff;

  /// No description provided for @legalDocumentsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hujjatlar'**
  String get legalDocumentsTitle;

  /// No description provided for @legalTerms.
  ///
  /// In uz, this message translates to:
  /// **'Foydalanish shartlari'**
  String get legalTerms;

  /// No description provided for @legalPrivacy.
  ///
  /// In uz, this message translates to:
  /// **'Maxfiylik siyosati'**
  String get legalPrivacy;

  /// No description provided for @legalFormatHint.
  ///
  /// In uz, this message translates to:
  /// **'## — sarlavha, - — ro\'yxat bandi, har bir qator — xatboshi'**
  String get legalFormatHint;

  /// No description provided for @legalPublishedBy.
  ///
  /// In uz, this message translates to:
  /// **'E\'lon qilindi: {date}, {name}'**
  String legalPublishedBy(String date, String name);

  /// No description provided for @legalNotPublished.
  ///
  /// In uz, this message translates to:
  /// **'E\'lon qilinmagan — ilovada qator ko\'rinmaydi'**
  String get legalNotPublished;

  /// No description provided for @legalPublish.
  ///
  /// In uz, this message translates to:
  /// **'E\'lon qilish'**
  String get legalPublish;

  /// No description provided for @legalUnpublishConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Hujjatni e\'londan olib tashlaysizmi?'**
  String get legalUnpublishConfirm;

  /// No description provided for @legalSaved.
  ///
  /// In uz, this message translates to:
  /// **'Hujjat e\'lon qilindi'**
  String get legalSaved;

  /// No description provided for @customersTitle.
  ///
  /// In uz, this message translates to:
  /// **'Xaridorlar'**
  String get customersTitle;

  /// No description provided for @customersSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Telefon raqami bo\'yicha qidirish'**
  String get customersSubtitle;

  /// No description provided for @customersPhoneLabel.
  ///
  /// In uz, this message translates to:
  /// **'Xaridor raqami'**
  String get customersPhoneLabel;

  /// No description provided for @customersPhoneHelper.
  ///
  /// In uz, this message translates to:
  /// **'To\'liq raqam: +998 dan keyin 9 raqam'**
  String get customersPhoneHelper;

  /// No description provided for @customersStartTitle.
  ///
  /// In uz, this message translates to:
  /// **'Xaridorni raqami bo\'yicha toping'**
  String get customersStartTitle;

  /// No description provided for @customersStartText.
  ///
  /// In uz, this message translates to:
  /// **'Raqamni to\'liq kiriting va «Topish»ni bosing.'**
  String get customersStartText;

  /// No description provided for @customersNoneHint.
  ///
  /// In uz, this message translates to:
  /// **'Raqamni tekshiring.'**
  String get customersNoneHint;

  /// No description provided for @customerOrdersLabel.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalar'**
  String get customerOrdersLabel;

  /// No description provided for @customerSince.
  ///
  /// In uz, this message translates to:
  /// **'Biz bilan'**
  String get customerSince;

  /// No description provided for @customerLastLoginLabel.
  ///
  /// In uz, this message translates to:
  /// **'Oxirgi kirish'**
  String get customerLastLoginLabel;

  /// No description provided for @customerUnfinishedExplained.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma tugagach, akkauntni o\'chirish mumkin.'**
  String get customerUnfinishedExplained;

  /// No description provided for @customerEraseFinal.
  ///
  /// In uz, this message translates to:
  /// **'O\'chirishni qaytarib bo\'lmaydi.'**
  String get customerEraseFinal;

  /// No description provided for @customersHelpTitle.
  ///
  /// In uz, this message translates to:
  /// **'So\'rov bo\'yicha akkauntni qanday o\'chirish kerak'**
  String get customersHelpTitle;

  /// No description provided for @customersHelpStep1.
  ///
  /// In uz, this message translates to:
  /// **'Ilovasi yo\'q xaridor qo\'llab-quvvatlashga qo\'ng\'iroq qiladi — saytdagi «Akkauntni o\'chirish» sahifasida shunday yozilgan.'**
  String get customersHelpStep1;

  /// No description provided for @customersHelpStep2.
  ///
  /// In uz, this message translates to:
  /// **'Uni bu yerda raqami bo\'yicha toping.'**
  String get customersHelpStep2;

  /// No description provided for @customersHelpStep3.
  ///
  /// In uz, this message translates to:
  /// **'«Akkauntni o\'chirish»ni bosing — darhol va qaytarib bo\'lmaydi. Tugallanmagan buyurtma bor ekan, o\'chirib bo\'lmaydi.'**
  String get customersHelpStep3;

  /// No description provided for @customersHelpPrivacy.
  ///
  /// In uz, this message translates to:
  /// **'Panel barcha xaridorlar ro\'yxatini ko\'rsatmaydi — faqat raqami kiritilganini.'**
  String get customersHelpPrivacy;

  /// No description provided for @customersPhoneHint.
  ///
  /// In uz, this message translates to:
  /// **'+998 va 9 raqam'**
  String get customersPhoneHint;

  /// No description provided for @customersFind.
  ///
  /// In uz, this message translates to:
  /// **'Topish'**
  String get customersFind;

  /// No description provided for @customersNone.
  ///
  /// In uz, this message translates to:
  /// **'Bu raqamli xaridor yo\'q'**
  String get customersNone;

  /// No description provided for @customerNoName.
  ///
  /// In uz, this message translates to:
  /// **'Ismsiz'**
  String get customerNoName;

  /// No description provided for @customerOrders.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalar: {count}'**
  String customerOrders(int count);

  /// No description provided for @customerUnfinished.
  ///
  /// In uz, this message translates to:
  /// **'Tugallanmagan buyurtma № {number}'**
  String customerUnfinished(String number);

  /// No description provided for @customerErase.
  ///
  /// In uz, this message translates to:
  /// **'Akkauntni o\'chirish'**
  String get customerErase;

  /// No description provided for @customerEraseBlockedNote.
  ///
  /// In uz, this message translates to:
  /// **'Akkaunt bloklangan: raqam qora ro\'yxatda qoladi, u bilan qayta ro\'yxatdan o\'tib bo\'lmaydi.'**
  String get customerEraseBlockedNote;

  /// No description provided for @customerEraseTitle.
  ///
  /// In uz, this message translates to:
  /// **'Xaridor akkauntini o\'chirasizmi?'**
  String get customerEraseTitle;

  /// No description provided for @customerEraseBody.
  ///
  /// In uz, this message translates to:
  /// **'Ism, raqam, manzillar, sevimlilar va savat o\'chiriladi. Buyurtmalar tarixi ism va telefonsiz qoladi.'**
  String get customerEraseBody;

  /// No description provided for @customerEraseConfirm.
  ///
  /// In uz, this message translates to:
  /// **'O\'chirish'**
  String get customerEraseConfirm;

  /// No description provided for @customerErased.
  ///
  /// In uz, this message translates to:
  /// **'Akkaunt o\'chirildi'**
  String get customerErased;

  /// No description provided for @orderCustomerErased.
  ///
  /// In uz, this message translates to:
  /// **'Xaridor ma\'lumotlari o\'chirilgan'**
  String get orderCustomerErased;

  /// No description provided for @roleShopper.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi'**
  String get roleShopper;

  /// No description provided for @roleCourier.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer'**
  String get roleCourier;

  /// No description provided for @roleOperator.
  ///
  /// In uz, this message translates to:
  /// **'Operator'**
  String get roleOperator;

  /// No description provided for @roleAdmin.
  ///
  /// In uz, this message translates to:
  /// **'Administrator'**
  String get roleAdmin;

  /// No description provided for @roleManager.
  ///
  /// In uz, this message translates to:
  /// **'Menejer'**
  String get roleManager;

  /// No description provided for @statusActive.
  ///
  /// In uz, this message translates to:
  /// **'Faol'**
  String get statusActive;

  /// No description provided for @statusBlocked.
  ///
  /// In uz, this message translates to:
  /// **'Bloklangan'**
  String get statusBlocked;

  /// No description provided for @staffNew.
  ///
  /// In uz, this message translates to:
  /// **'Yangi xodim'**
  String get staffNew;

  /// No description provided for @staffNewSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Vaqtinchalik parol saqlangandan keyin chiqadi — u bir marta ko\'rsatiladi'**
  String get staffNewSubtitle;

  /// No description provided for @staffRoleShopperHint.
  ///
  /// In uz, this message translates to:
  /// **'Ilova: buyurtmalarni bozordan xarid qiladi'**
  String get staffRoleShopperHint;

  /// No description provided for @staffRoleCourierHint.
  ///
  /// In uz, this message translates to:
  /// **'Ilova: buyurtmalarni mijozlarga yetkazadi'**
  String get staffRoleCourierHint;

  /// No description provided for @staffRoleOperatorHint.
  ///
  /// In uz, this message translates to:
  /// **'Panel: buyurtmalar, savollar va bekor qilishlar'**
  String get staffRoleOperatorHint;

  /// No description provided for @staffRoleAdminHint.
  ///
  /// In uz, this message translates to:
  /// **'Panel: hammasi, katalog va sozlamalar ham'**
  String get staffRoleAdminHint;

  /// No description provided for @staffRoleManagerHint.
  ///
  /// In uz, this message translates to:
  /// **'Faqat ko\'rish'**
  String get staffRoleManagerHint;

  /// No description provided for @staffRoleFixedNote.
  ///
  /// In uz, this message translates to:
  /// **'Rol keyin o\'zgarmaydi. Rolni almashtirish uchun xodimni bloklang va o\'sha raqamga yangi akkaunt yarating.'**
  String get staffRoleFixedNote;

  /// No description provided for @staffBlockTitle.
  ///
  /// In uz, this message translates to:
  /// **'Xodim bloklansinmi?'**
  String get staffBlockTitle;

  /// No description provided for @staffBlockSessions.
  ///
  /// In uz, this message translates to:
  /// **'Bu xodimning barcha seanslari darhol tugaydi.'**
  String get staffBlockSessions;

  /// No description provided for @staffResetTitle.
  ///
  /// In uz, this message translates to:
  /// **'Parol tiklansinmi?'**
  String get staffResetTitle;

  /// No description provided for @staffResetExplained.
  ///
  /// In uz, this message translates to:
  /// **'Yangi vaqtinchalik parol yaratamiz, bu xodimning barcha seanslari tugaydi.'**
  String get staffResetExplained;

  /// No description provided for @staffFullName.
  ///
  /// In uz, this message translates to:
  /// **'To\'liq ism'**
  String get staffFullName;

  /// No description provided for @staffRole.
  ///
  /// In uz, this message translates to:
  /// **'Rol'**
  String get staffRole;

  /// No description provided for @staffAllRoles.
  ///
  /// In uz, this message translates to:
  /// **'Barcha rollar'**
  String get staffAllRoles;

  /// No description provided for @staffAllStatuses.
  ///
  /// In uz, this message translates to:
  /// **'Barcha holatlar'**
  String get staffAllStatuses;

  /// No description provided for @staffNoName.
  ///
  /// In uz, this message translates to:
  /// **'Ism kiritilmagan'**
  String get staffNoName;

  /// No description provided for @staffYou.
  ///
  /// In uz, this message translates to:
  /// **'Siz'**
  String get staffYou;

  /// No description provided for @staffEditName.
  ///
  /// In uz, this message translates to:
  /// **'Ismni o\'zgartirish'**
  String get staffEditName;

  /// No description provided for @staffBlock.
  ///
  /// In uz, this message translates to:
  /// **'Bloklash'**
  String get staffBlock;

  /// No description provided for @staffActivate.
  ///
  /// In uz, this message translates to:
  /// **'Blokdan chiqarish'**
  String get staffActivate;

  /// No description provided for @staffResetPassword.
  ///
  /// In uz, this message translates to:
  /// **'Parolni tiklash'**
  String get staffResetPassword;

  /// No description provided for @staffTemporaryPasswordTitle.
  ///
  /// In uz, this message translates to:
  /// **'Vaqtinchalik parol'**
  String get staffTemporaryPasswordTitle;

  /// No description provided for @staffTemporaryPasswordWarning.
  ///
  /// In uz, this message translates to:
  /// **'Parolni hozir nusxalab, xodimga bering. U boshqa ko\'rsatilmaydi. Birinchi kirishda xodim o\'z parolini o\'rnatadi.'**
  String get staffTemporaryPasswordWarning;

  /// No description provided for @staffCopy.
  ///
  /// In uz, this message translates to:
  /// **'Nusxalash'**
  String get staffCopy;

  /// No description provided for @staffCopied.
  ///
  /// In uz, this message translates to:
  /// **'Nusxalandi'**
  String get staffCopied;

  /// No description provided for @staffDone.
  ///
  /// In uz, this message translates to:
  /// **'Tayyor'**
  String get staffDone;

  /// No description provided for @staffMustChangePassword.
  ///
  /// In uz, this message translates to:
  /// **'Parolni almashtirishi kerak'**
  String get staffMustChangePassword;

  /// No description provided for @staffLastLogin.
  ///
  /// In uz, this message translates to:
  /// **'Oxirgi kirish: {when}'**
  String staffLastLogin(String when);

  /// No description provided for @staffNeverLoggedIn.
  ///
  /// In uz, this message translates to:
  /// **'Hali kirmagan'**
  String get staffNeverLoggedIn;

  /// No description provided for @staffCount.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta xodim'**
  String staffCount(int count);

  /// No description provided for @staffRoleShoppers.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchilar'**
  String get staffRoleShoppers;

  /// No description provided for @staffRoleCouriers.
  ///
  /// In uz, this message translates to:
  /// **'Kuryerlar'**
  String get staffRoleCouriers;

  /// No description provided for @staffRoleOperators.
  ///
  /// In uz, this message translates to:
  /// **'Operatorlar'**
  String get staffRoleOperators;

  /// No description provided for @staffRoleAdmins.
  ///
  /// In uz, this message translates to:
  /// **'Administratorlar'**
  String get staffRoleAdmins;

  /// No description provided for @staffRoleManagers.
  ///
  /// In uz, this message translates to:
  /// **'Menejerlar'**
  String get staffRoleManagers;

  /// No description provided for @staffColumnMember.
  ///
  /// In uz, this message translates to:
  /// **'Xodim'**
  String get staffColumnMember;

  /// No description provided for @staffColumnStatus.
  ///
  /// In uz, this message translates to:
  /// **'Holati'**
  String get staffColumnStatus;

  /// No description provided for @staffColumnLastLogin.
  ///
  /// In uz, this message translates to:
  /// **'Oxirgi kirish'**
  String get staffColumnLastLogin;

  /// No description provided for @staffEmptyHint.
  ///
  /// In uz, this message translates to:
  /// **'Boshqa rolni yoki «Barcha holatlar»ni tanlang.'**
  String get staffEmptyHint;

  /// No description provided for @staffSaved.
  ///
  /// In uz, this message translates to:
  /// **'Saqlandi'**
  String get staffSaved;

  /// No description provided for @errorSelfBlockNotAllowed.
  ///
  /// In uz, this message translates to:
  /// **'O\'zingizni bloklay olmaysiz'**
  String get errorSelfBlockNotAllowed;

  /// No description provided for @errorLastActiveAdminRequired.
  ///
  /// In uz, this message translates to:
  /// **'Oxirgi faol administratorni bloklab bo\'lmaydi'**
  String get errorLastActiveAdminRequired;

  /// No description provided for @errorSelfResetNotAllowed.
  ///
  /// In uz, this message translates to:
  /// **'O\'z parolingizni bu yerda tiklab bo\'lmaydi'**
  String get errorSelfResetNotAllowed;

  /// No description provided for @errorPhoneAlreadyActive.
  ///
  /// In uz, this message translates to:
  /// **'Bu raqam boshqa faol xodimga tegishli'**
  String get errorPhoneAlreadyActive;

  /// No description provided for @catalogSearchHint.
  ///
  /// In uz, this message translates to:
  /// **'Qidirish: bodring, non…'**
  String get catalogSearchHint;

  /// No description provided for @deliveryAddressEmptyHint.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmani qayerga olib borish kerak'**
  String get deliveryAddressEmptyHint;

  /// No description provided for @homeCategories.
  ///
  /// In uz, this message translates to:
  /// **'Kategoriyalar'**
  String get homeCategories;

  /// No description provided for @homeSeeAll.
  ///
  /// In uz, this message translates to:
  /// **'Barchasi'**
  String get homeSeeAll;

  /// No description provided for @deliveryAddressAdd.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazish manzilini qo\'shing'**
  String get deliveryAddressAdd;

  /// No description provided for @deliveryAddressRetry.
  ///
  /// In uz, this message translates to:
  /// **'Manzil yuklanmadi — qayta urinish'**
  String get deliveryAddressRetry;

  /// No description provided for @deliveryAddressSheetTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazish manzili'**
  String get deliveryAddressSheetTitle;

  /// No description provided for @catalogSearchClear.
  ///
  /// In uz, this message translates to:
  /// **'Tozalash'**
  String get catalogSearchClear;

  /// No description provided for @catalogCategoriesTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bo\'limlar'**
  String get catalogCategoriesTitle;

  /// No description provided for @catalogNoProducts.
  ///
  /// In uz, this message translates to:
  /// **'Bu yerda hozircha mahsulot yo\'q'**
  String get catalogNoProducts;

  /// No description provided for @catalogPricePerUnit.
  ///
  /// In uz, this message translates to:
  /// **'{price} / {unit}'**
  String catalogPricePerUnit(String price, String unit);

  /// No description provided for @catalogEstimateExplain.
  ///
  /// In uz, this message translates to:
  /// **'Yakuniy narx yig\'uvchi bozorda haqiqatda to\'lagan narxdan hisoblanadi. U taxminiy narxdan belgilangan chegaradan ko\'proq oshsa, xarid qilishdan oldin sizdan rozilik so\'raymiz.'**
  String get catalogEstimateExplain;

  /// No description provided for @catalogLoadMore.
  ///
  /// In uz, this message translates to:
  /// **'Yana yuklash'**
  String get catalogLoadMore;

  /// No description provided for @homeNavHome.
  ///
  /// In uz, this message translates to:
  /// **'Bosh sahifa'**
  String get homeNavHome;

  /// No description provided for @homeNavOrders.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalar'**
  String get homeNavOrders;

  /// No description provided for @profileTitle.
  ///
  /// In uz, this message translates to:
  /// **'Profil'**
  String get profileTitle;

  /// No description provided for @profileNoName.
  ///
  /// In uz, this message translates to:
  /// **'Ismingiz nima?'**
  String get profileNoName;

  /// No description provided for @profileEdit.
  ///
  /// In uz, this message translates to:
  /// **'Profilni tahrirlash'**
  String get profileEdit;

  /// No description provided for @profileSetName.
  ///
  /// In uz, this message translates to:
  /// **'Ismni kiritish'**
  String get profileSetName;

  /// No description provided for @profileLanguage.
  ///
  /// In uz, this message translates to:
  /// **'Til'**
  String get profileLanguage;

  /// No description provided for @profileSupport.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'llab-quvvatlash'**
  String get profileSupport;

  /// No description provided for @profilePrivacy.
  ///
  /// In uz, this message translates to:
  /// **'Maxfiylik'**
  String get profilePrivacy;

  /// No description provided for @profileName.
  ///
  /// In uz, this message translates to:
  /// **'Ismingiz'**
  String get profileName;

  /// No description provided for @profileSaved.
  ///
  /// In uz, this message translates to:
  /// **'Ism saqlandi'**
  String get profileSaved;

  /// No description provided for @profileEditTitle.
  ///
  /// In uz, this message translates to:
  /// **'Profilni tahrirlash'**
  String get profileEditTitle;

  /// No description provided for @profileNameLabel.
  ///
  /// In uz, this message translates to:
  /// **'Ism'**
  String get profileNameLabel;

  /// No description provided for @profilePhoneLabel.
  ///
  /// In uz, this message translates to:
  /// **'Telefon raqami'**
  String get profilePhoneLabel;

  /// No description provided for @profilePhoneLocked.
  ///
  /// In uz, this message translates to:
  /// **'Raqam — ilovaga kirishingiz, uni o\'zgartirib bo\'lmaydi.'**
  String get profilePhoneLocked;

  /// No description provided for @profileNameRequired.
  ///
  /// In uz, this message translates to:
  /// **'Ismni kiriting — usiz buyurtma berib bo\'lmaydi.'**
  String get profileNameRequired;

  /// No description provided for @addressesTitle.
  ///
  /// In uz, this message translates to:
  /// **'Manzillarim'**
  String get addressesTitle;

  /// No description provided for @addressNone.
  ///
  /// In uz, this message translates to:
  /// **'Hali manzil qo\'shilmagan'**
  String get addressNone;

  /// No description provided for @addressNew.
  ///
  /// In uz, this message translates to:
  /// **'Yangi manzil'**
  String get addressNew;

  /// No description provided for @addressEdit.
  ///
  /// In uz, this message translates to:
  /// **'Manzilni tahrirlash'**
  String get addressEdit;

  /// No description provided for @addressHouse.
  ///
  /// In uz, this message translates to:
  /// **'Uy'**
  String get addressHouse;

  /// No description provided for @addressApartment.
  ///
  /// In uz, this message translates to:
  /// **'Xonadon'**
  String get addressApartment;

  /// No description provided for @addressLandmark.
  ///
  /// In uz, this message translates to:
  /// **'Mo\'ljal'**
  String get addressLandmark;

  /// No description provided for @addressDeliveryNote.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer uchun izoh'**
  String get addressDeliveryNote;

  /// No description provided for @addressFieldStreet.
  ///
  /// In uz, this message translates to:
  /// **'Ko\'cha, massiv yoki mavze'**
  String get addressFieldStreet;

  /// No description provided for @addressFieldApartment.
  ///
  /// In uz, this message translates to:
  /// **'Xonadon yoki ofis'**
  String get addressFieldApartment;

  /// No description provided for @addressLandmarkHint.
  ///
  /// In uz, this message translates to:
  /// **'Masalan: 64-maktab qarshisida'**
  String get addressLandmarkHint;

  /// No description provided for @addressFieldNote.
  ///
  /// In uz, this message translates to:
  /// **'Kuryerga izoh'**
  String get addressFieldNote;

  /// No description provided for @addressNoteHint.
  ///
  /// In uz, this message translates to:
  /// **'Podyezd, qavat, domofon kodi'**
  String get addressNoteHint;

  /// No description provided for @addressLabelTitle.
  ///
  /// In uz, this message translates to:
  /// **'Manzil nomi'**
  String get addressLabelTitle;

  /// No description provided for @addressLabelHome.
  ///
  /// In uz, this message translates to:
  /// **'Uy'**
  String get addressLabelHome;

  /// No description provided for @addressLabelWork.
  ///
  /// In uz, this message translates to:
  /// **'Ish'**
  String get addressLabelWork;

  /// No description provided for @addressLabelCustom.
  ///
  /// In uz, this message translates to:
  /// **'Boshqa'**
  String get addressLabelCustom;

  /// No description provided for @addressLabelName.
  ///
  /// In uz, this message translates to:
  /// **'Nomi'**
  String get addressLabelName;

  /// No description provided for @addressChangePoint.
  ///
  /// In uz, this message translates to:
  /// **'Nuqtani o\'zgartirish'**
  String get addressChangePoint;

  /// No description provided for @addressSaveButton.
  ///
  /// In uz, this message translates to:
  /// **'Manzilni saqlash'**
  String get addressSaveButton;

  /// No description provided for @addressMapHint.
  ///
  /// In uz, this message translates to:
  /// **'Xaritani suring: belgi uyingiz kirish joyida tursin'**
  String get addressMapHint;

  /// No description provided for @addressPointTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazish nuqtasi'**
  String get addressPointTitle;

  /// No description provided for @addressSearchHint.
  ///
  /// In uz, this message translates to:
  /// **'Yoki manzilni yozing: ko\'cha, uy'**
  String get addressSearchHint;

  /// No description provided for @addressSearchFound.
  ///
  /// In uz, this message translates to:
  /// **'Belgini tekshiring: kuryer aynan unga keladi'**
  String get addressSearchFound;

  /// No description provided for @addressPointText.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer belgiga keladi. Xonadon, podyezd va mo\'ljalni keyingi qadamda kiritasiz.'**
  String get addressPointText;

  /// No description provided for @addressSearchNotFound.
  ///
  /// In uz, this message translates to:
  /// **'Xaritada bunday manzil topilmadi. Xaritani surib, belgini uyingizga o\'zingiz qo\'ying.'**
  String get addressSearchNotFound;

  /// No description provided for @addressSearchUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Manzil qidiruvi hozir ishlamayapti. Xaritani surib, belgini o\'zingiz qo\'ying.'**
  String get addressSearchUnavailable;

  /// No description provided for @addressWordsKept.
  ///
  /// In uz, this message translates to:
  /// **'Yozgan manzilingizni kuryer uchun saqlaymiz'**
  String get addressWordsKept;

  /// No description provided for @addressMyLocation.
  ///
  /// In uz, this message translates to:
  /// **'Men qayerdaman'**
  String get addressMyLocation;

  /// No description provided for @addressLocationFailed.
  ///
  /// In uz, this message translates to:
  /// **'Joylashuvingizni aniqlab bo\'lmadi. Xaritani o\'zingiz suring.'**
  String get addressLocationFailed;

  /// No description provided for @addressSearchClear.
  ///
  /// In uz, this message translates to:
  /// **'Tozalash'**
  String get addressSearchClear;

  /// No description provided for @addressPointConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Nuqtani tasdiqlash'**
  String get addressPointConfirm;

  /// No description provided for @addressMapUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Bu ilova versiyasida xarita yo\'q. Nuqtaning koordinatalarini kiriting'**
  String get addressMapUnavailable;

  /// No description provided for @addressLatitude.
  ///
  /// In uz, this message translates to:
  /// **'Kenglik'**
  String get addressLatitude;

  /// No description provided for @addressLongitude.
  ///
  /// In uz, this message translates to:
  /// **'Uzunlik'**
  String get addressLongitude;

  /// No description provided for @addressLatitudeInvalid.
  ///
  /// In uz, this message translates to:
  /// **'Kenglik -90 dan 90 gacha son bo\'lishi kerak'**
  String get addressLatitudeInvalid;

  /// No description provided for @addressLongitudeInvalid.
  ///
  /// In uz, this message translates to:
  /// **'Uzunlik -180 dan 180 gacha son bo\'lishi kerak'**
  String get addressLongitudeInvalid;

  /// No description provided for @addressOutsideAreaPlain.
  ///
  /// In uz, this message translates to:
  /// **'Bu manzil yetkazib berish hududidan tashqarida'**
  String get addressOutsideAreaPlain;

  /// No description provided for @noChanges.
  ///
  /// In uz, this message translates to:
  /// **'O\'zgarish yo\'q'**
  String get noChanges;

  /// No description provided for @addressOutsideArea.
  ///
  /// In uz, this message translates to:
  /// **'Bu manzil yetkazib berish hududidan tashqarida: {distance} km. Biz {max} km gacha yetkazib beramiz'**
  String addressOutsideArea(String distance, String max);

  /// No description provided for @addressSaved.
  ///
  /// In uz, this message translates to:
  /// **'Manzil saqlandi'**
  String get addressSaved;

  /// No description provided for @addressAddNew.
  ///
  /// In uz, this message translates to:
  /// **'Yangi manzil qo\'shish'**
  String get addressAddNew;

  /// No description provided for @addressMenuEdit.
  ///
  /// In uz, this message translates to:
  /// **'O\'zgartirish'**
  String get addressMenuEdit;

  /// No description provided for @addressLandmarkLine.
  ///
  /// In uz, this message translates to:
  /// **'Mo\'ljal: {landmark}'**
  String addressLandmarkLine(String landmark);

  /// No description provided for @addressApartmentShort.
  ///
  /// In uz, this message translates to:
  /// **'{apartment}-xonadon'**
  String addressApartmentShort(String apartment);

  /// No description provided for @addressRemove.
  ///
  /// In uz, this message translates to:
  /// **'O\'chirish'**
  String get addressRemove;

  /// No description provided for @addressRemoveConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Bu manzil o\'chirilsinmi?'**
  String get addressRemoveConfirm;

  /// No description provided for @errorConfigurationIncomplete.
  ///
  /// In uz, this message translates to:
  /// **'Xizmat hali to\'liq sozlanmagan. Keyinroq urinib ko\'ring'**
  String get errorConfigurationIncomplete;

  /// No description provided for @orderStatusNew.
  ///
  /// In uz, this message translates to:
  /// **'Yangi'**
  String get orderStatusNew;

  /// No description provided for @orderStatusShoppingAssigned.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi tayinlangan'**
  String get orderStatusShoppingAssigned;

  /// No description provided for @orderStatusShopping.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'ilmoqda'**
  String get orderStatusShopping;

  /// No description provided for @orderStatusFinalPaymentPending.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov kutilmoqda'**
  String get orderStatusFinalPaymentPending;

  /// No description provided for @orderStatusReadyForDelivery.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazishga tayyor'**
  String get orderStatusReadyForDelivery;

  /// No description provided for @orderStatusDeliveryAssigned.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer tayinlangan'**
  String get orderStatusDeliveryAssigned;

  /// No description provided for @orderStatusOnTheWay.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'lda'**
  String get orderStatusOnTheWay;

  /// No description provided for @orderStatusCompleted.
  ///
  /// In uz, this message translates to:
  /// **'Yakunlangan'**
  String get orderStatusCompleted;

  /// No description provided for @orderStatusCancelled.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilingan'**
  String get orderStatusCancelled;

  /// No description provided for @paymentCash.
  ///
  /// In uz, this message translates to:
  /// **'Naqd pul'**
  String get paymentCash;

  /// No description provided for @paymentOnline.
  ///
  /// In uz, this message translates to:
  /// **'Onlayn'**
  String get paymentOnline;

  /// No description provided for @totalKindEstimate.
  ///
  /// In uz, this message translates to:
  /// **'taxminiy'**
  String get totalKindEstimate;

  /// No description provided for @totalKindFinal.
  ///
  /// In uz, this message translates to:
  /// **'yakuniy'**
  String get totalKindFinal;

  /// No description provided for @totalNothingDue.
  ///
  /// In uz, this message translates to:
  /// **'To\'lanmaydi'**
  String get totalNothingDue;

  /// No description provided for @itemStatusPending.
  ///
  /// In uz, this message translates to:
  /// **'Kutilmoqda'**
  String get itemStatusPending;

  /// No description provided for @itemStatusAwaitingCustomer.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz javobi kutilmoqda'**
  String get itemStatusAwaitingCustomer;

  /// No description provided for @itemStatusPurchased.
  ///
  /// In uz, this message translates to:
  /// **'Sotib olindi'**
  String get itemStatusPurchased;

  /// No description provided for @itemStatusRemoved.
  ///
  /// In uz, this message translates to:
  /// **'Olib tashlandi'**
  String get itemStatusRemoved;

  /// No description provided for @substitutionAllowSimilar.
  ///
  /// In uz, this message translates to:
  /// **'O\'xshashi bilan almashtirish mumkin'**
  String get substitutionAllowSimilar;

  /// No description provided for @substitutionContactBefore.
  ///
  /// In uz, this message translates to:
  /// **'Almashtirishdan oldin bog\'lanish'**
  String get substitutionContactBefore;

  /// No description provided for @substitutionRemoveIfUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Bo\'lmasa, olib tashlash'**
  String get substitutionRemoveIfUnavailable;

  /// No description provided for @removedUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'mahsulot topilmadi'**
  String get removedUnavailable;

  /// No description provided for @removedCustomerRejected.
  ///
  /// In uz, this message translates to:
  /// **'mijoz rad etdi'**
  String get removedCustomerRejected;

  /// No description provided for @removedApprovalExpired.
  ///
  /// In uz, this message translates to:
  /// **'javob muddati o\'tdi'**
  String get removedApprovalExpired;

  /// No description provided for @removedCustomerRemoved.
  ///
  /// In uz, this message translates to:
  /// **'mijoz olib tashladi'**
  String get removedCustomerRemoved;

  /// No description provided for @removedOperatorRemoved.
  ///
  /// In uz, this message translates to:
  /// **'operator olib tashladi'**
  String get removedOperatorRemoved;

  /// No description provided for @removedOrderCancelled.
  ///
  /// In uz, this message translates to:
  /// **'buyurtma bekor qilindi'**
  String get removedOrderCancelled;

  /// No description provided for @cancelCustomerCancelled.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz bekor qildi'**
  String get cancelCustomerCancelled;

  /// No description provided for @cancelRequestApproved.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish so\'rovi qabul qilindi'**
  String get cancelRequestApproved;

  /// No description provided for @cancelUnpaidOnline.
  ///
  /// In uz, this message translates to:
  /// **'Onlayn to\'lov qilinmadi'**
  String get cancelUnpaidOnline;

  /// No description provided for @cancelNoItemsPurchased.
  ///
  /// In uz, this message translates to:
  /// **'Hech narsa sotib olinmadi'**
  String get cancelNoItemsPurchased;

  /// No description provided for @cancelDeliveryFailed.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazib bo\'lmadi'**
  String get cancelDeliveryFailed;

  /// No description provided for @cancelSystem.
  ///
  /// In uz, this message translates to:
  /// **'Tizim bekor qildi'**
  String get cancelSystem;

  /// No description provided for @boardRefresh.
  ///
  /// In uz, this message translates to:
  /// **'Yangilash'**
  String get boardRefresh;

  /// No description provided for @boardSearch.
  ///
  /// In uz, this message translates to:
  /// **'Raqam, telefon yoki ism'**
  String get boardSearch;

  /// No description provided for @boardAllPaymentMethods.
  ///
  /// In uz, this message translates to:
  /// **'Barcha to\'lov usullari'**
  String get boardAllPaymentMethods;

  /// No description provided for @boardAllShoppers.
  ///
  /// In uz, this message translates to:
  /// **'Barcha yig\'uvchilar'**
  String get boardAllShoppers;

  /// No description provided for @boardDays.
  ///
  /// In uz, this message translates to:
  /// **'Sanalar'**
  String get boardDays;

  /// No description provided for @boardClearDays.
  ///
  /// In uz, this message translates to:
  /// **'Sanalarni tozalash'**
  String get boardClearDays;

  /// No description provided for @boardSelfOrdersOnly.
  ///
  /// In uz, this message translates to:
  /// **'Faqat o\'zi uchun buyurtmalar'**
  String get boardSelfOrdersOnly;

  /// No description provided for @boardClearFilters.
  ///
  /// In uz, this message translates to:
  /// **'Filtrlarni tozalash'**
  String get boardClearFilters;

  /// No description provided for @boardEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha buyurtma yo\'q'**
  String get boardEmpty;

  /// No description provided for @boardEmptyFiltered.
  ///
  /// In uz, this message translates to:
  /// **'Filtrlarga mos buyurtma yo\'q'**
  String get boardEmptyFiltered;

  /// No description provided for @boardColumnOrder.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma'**
  String get boardColumnOrder;

  /// No description provided for @boardFilters.
  ///
  /// In uz, this message translates to:
  /// **'Filtrlar'**
  String get boardFilters;

  /// No description provided for @boardNoCourier.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer tayinlanmagan'**
  String get boardNoCourier;

  /// No description provided for @boardPageRange.
  ///
  /// In uz, this message translates to:
  /// **'{total} tadan {from}–{to}'**
  String boardPageRange(int from, int to, int total);

  /// No description provided for @boardColumnCustomer.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz'**
  String get boardColumnCustomer;

  /// No description provided for @boardColumnStatus.
  ///
  /// In uz, this message translates to:
  /// **'Holat'**
  String get boardColumnStatus;

  /// No description provided for @boardColumnPayment.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov'**
  String get boardColumnPayment;

  /// No description provided for @boardColumnTotal.
  ///
  /// In uz, this message translates to:
  /// **'Summa'**
  String get boardColumnTotal;

  /// No description provided for @boardItemCount.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta mahsulot'**
  String boardItemCount(int count);

  /// No description provided for @boardNoShopper.
  ///
  /// In uz, this message translates to:
  /// **'Tayinlanmagan'**
  String get boardNoShopper;

  /// No description provided for @boardOrderNumber.
  ///
  /// In uz, this message translates to:
  /// **'№{number}'**
  String boardOrderNumber(String number);

  /// No description provided for @selfOrderMark.
  ///
  /// In uz, this message translates to:
  /// **'O\'zi uchun'**
  String get selfOrderMark;

  /// No description provided for @selfOrderExplained.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi — buyurtmachining o\'zi'**
  String get selfOrderExplained;

  /// No description provided for @summaryCompletedToday.
  ///
  /// In uz, this message translates to:
  /// **'Bugun yakunlangan'**
  String get summaryCompletedToday;

  /// No description provided for @summaryCancelledToday.
  ///
  /// In uz, this message translates to:
  /// **'Bugun bekor qilingan'**
  String get summaryCancelledToday;

  /// No description provided for @summarySalesToday.
  ///
  /// In uz, this message translates to:
  /// **'Bugungi savdo'**
  String get summarySalesToday;

  /// No description provided for @summaryOpen.
  ///
  /// In uz, this message translates to:
  /// **'Jarayonda'**
  String get summaryOpen;

  /// No description provided for @boardAllOrders.
  ///
  /// In uz, this message translates to:
  /// **'Barcha buyurtmalar'**
  String get boardAllOrders;

  /// No description provided for @boardUpdatedAt.
  ///
  /// In uz, this message translates to:
  /// **'{time} da yangilandi'**
  String boardUpdatedAt(String time);

  /// No description provided for @attentionLongestFirst.
  ///
  /// In uz, this message translates to:
  /// **'Uzoq kutganlar — tepada'**
  String get attentionLongestFirst;

  /// No description provided for @attentionWaitingMinutes.
  ///
  /// In uz, this message translates to:
  /// **'{minutes} daq'**
  String attentionWaitingMinutes(int minutes);

  /// No description provided for @attentionWaitingHours.
  ///
  /// In uz, this message translates to:
  /// **'{hours} soat {minutes} daq'**
  String attentionWaitingHours(int hours, int minutes);

  /// No description provided for @attentionTitle.
  ///
  /// In uz, this message translates to:
  /// **'E\'tibor talab qiladi'**
  String get attentionTitle;

  /// No description provided for @attentionEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha hech narsa yo\'q'**
  String get attentionEmpty;

  /// No description provided for @attentionApprovalPending.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz 10 daqiqadan beri javob bermayapti — qo\'ng\'iroq qiling'**
  String get attentionApprovalPending;

  /// No description provided for @attentionApprovalExpired.
  ///
  /// In uz, this message translates to:
  /// **'Mijozning javob muddati o\'tdi — mahsulotni olib tashlang'**
  String get attentionApprovalExpired;

  /// No description provided for @attentionPaymentOverdue.
  ///
  /// In uz, this message translates to:
  /// **'Onlayn to\'lov kechikmoqda'**
  String get attentionPaymentOverdue;

  /// No description provided for @attentionRefundOutstanding.
  ///
  /// In uz, this message translates to:
  /// **'Pulni qaytarish kutilmoqda'**
  String get attentionRefundOutstanding;

  /// No description provided for @attentionCourierDelayed.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer kechikmoqda'**
  String get attentionCourierDelayed;

  /// No description provided for @attentionDeliveryFailed.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazib bo\'lmadi — kuryer tayinlang yoki bekor qiling'**
  String get attentionDeliveryFailed;

  /// No description provided for @attentionCancellationRequest.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz bekor qilishni so\'ramoqda'**
  String get attentionCancellationRequest;

  /// No description provided for @attentionStaffBlocked.
  ///
  /// In uz, this message translates to:
  /// **'Ijrochi bloklangan — boshqasini tayinlang'**
  String get attentionStaffBlocked;

  /// No description provided for @attentionOther.
  ///
  /// In uz, this message translates to:
  /// **'E\'tibor talab qiladi'**
  String get attentionOther;

  /// No description provided for @attentionSince.
  ///
  /// In uz, this message translates to:
  /// **'{time} dan beri'**
  String attentionSince(String time);

  /// No description provided for @orderTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma №{number}'**
  String orderTitle(String number);

  /// No description provided for @orderPathCreated.
  ///
  /// In uz, this message translates to:
  /// **'Yaratildi'**
  String get orderPathCreated;

  /// No description provided for @orderPathShopping.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'ish'**
  String get orderPathShopping;

  /// No description provided for @orderPathRunning.
  ///
  /// In uz, this message translates to:
  /// **'{time} dan beri'**
  String orderPathRunning(String time);

  /// No description provided for @orderPathWaiting.
  ///
  /// In uz, this message translates to:
  /// **'{time} dan kutmoqda'**
  String orderPathWaiting(String time);

  /// No description provided for @orderCourierLater.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma yetkazishga tayyor bo\'lganda tayinlash mumkin'**
  String get orderCourierLater;

  /// No description provided for @orderBackToBoard.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalarga qaytish'**
  String get orderBackToBoard;

  /// No description provided for @orderPlacedAt.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilingan: {time}'**
  String orderPlacedAt(String time);

  /// No description provided for @orderSectionCustomer.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz'**
  String get orderSectionCustomer;

  /// No description provided for @orderSectionAddress.
  ///
  /// In uz, this message translates to:
  /// **'Manzil'**
  String get orderSectionAddress;

  /// No description provided for @orderSectionDeliveryWish.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazish vaqti bo\'yicha istak'**
  String get orderSectionDeliveryWish;

  /// No description provided for @orderSectionItems.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlar'**
  String get orderSectionItems;

  /// No description provided for @orderSectionTotals.
  ///
  /// In uz, this message translates to:
  /// **'Hisob'**
  String get orderSectionTotals;

  /// No description provided for @orderSectionShoppers.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchilar'**
  String get orderSectionShoppers;

  /// No description provided for @orderSectionHistory.
  ///
  /// In uz, this message translates to:
  /// **'Tarix'**
  String get orderSectionHistory;

  /// No description provided for @orderNoDeliveryWish.
  ///
  /// In uz, this message translates to:
  /// **'Istak yo\'q'**
  String get orderNoDeliveryWish;

  /// No description provided for @orderCoordinates.
  ///
  /// In uz, this message translates to:
  /// **'Koordinatalar: {latitude}, {longitude}'**
  String orderCoordinates(String latitude, String longitude);

  /// No description provided for @itemMarketPrice.
  ///
  /// In uz, this message translates to:
  /// **'Bozor narxi: {price}'**
  String itemMarketPrice(String price);

  /// No description provided for @itemMarkup.
  ///
  /// In uz, this message translates to:
  /// **'Ustama: {percent}%'**
  String itemMarkup(String percent);

  /// No description provided for @itemNote.
  ///
  /// In uz, this message translates to:
  /// **'Izoh: {note}'**
  String itemNote(String note);

  /// No description provided for @itemRemovedBecause.
  ///
  /// In uz, this message translates to:
  /// **'Olib tashlandi: {reason}'**
  String itemRemovedBecause(String reason);

  /// No description provided for @totalsMerchandise.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlar'**
  String get totalsMerchandise;

  /// No description provided for @totalsServiceFee.
  ///
  /// In uz, this message translates to:
  /// **'Xizmat haqi'**
  String get totalsServiceFee;

  /// No description provided for @totalsDeliveryFee.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazib berish'**
  String get totalsDeliveryFee;

  /// No description provided for @totalsTotal.
  ///
  /// In uz, this message translates to:
  /// **'Jami'**
  String get totalsTotal;

  /// No description provided for @assignmentCurrent.
  ///
  /// In uz, this message translates to:
  /// **'Hozirgi'**
  String get assignmentCurrent;

  /// No description provided for @assignmentAssignedBy.
  ///
  /// In uz, this message translates to:
  /// **'{name} tayinladi, {time}'**
  String assignmentAssignedBy(String name, String time);

  /// No description provided for @assignmentAccepted.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qildi: {time}'**
  String assignmentAccepted(String time);

  /// No description provided for @assignmentStarted.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'ishni boshladi: {time}'**
  String assignmentStarted(String time);

  /// No description provided for @assignmentEnded.
  ///
  /// In uz, this message translates to:
  /// **'Tugadi: {time}, {reason}'**
  String assignmentEnded(String time, String reason);

  /// No description provided for @assignmentEndCompleted.
  ///
  /// In uz, this message translates to:
  /// **'yig\'ish yakunlandi'**
  String get assignmentEndCompleted;

  /// No description provided for @assignmentEndReassigned.
  ///
  /// In uz, this message translates to:
  /// **'boshqa yig\'uvchiga o\'tkazildi'**
  String get assignmentEndReassigned;

  /// No description provided for @assignmentEndOrderCancelled.
  ///
  /// In uz, this message translates to:
  /// **'buyurtma bekor qilindi'**
  String get assignmentEndOrderCancelled;

  /// No description provided for @assignmentsNone.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi hali tayinlanmagan'**
  String get assignmentsNone;

  /// No description provided for @personWithoutName.
  ///
  /// In uz, this message translates to:
  /// **'Ismsiz'**
  String get personWithoutName;

  /// No description provided for @historyNone.
  ///
  /// In uz, this message translates to:
  /// **'Tarix hali bo\'sh'**
  String get historyNone;

  /// No description provided for @historySystem.
  ///
  /// In uz, this message translates to:
  /// **'Tizim'**
  String get historySystem;

  /// No description provided for @historyPaymentProvider.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov tizimi'**
  String get historyPaymentProvider;

  /// No description provided for @historyEventStatusChanged.
  ///
  /// In uz, this message translates to:
  /// **'Holat o\'zgardi'**
  String get historyEventStatusChanged;

  /// No description provided for @historyEventEdited.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma o\'zgartirildi'**
  String get historyEventEdited;

  /// No description provided for @historyEventPaymentMethodSwitched.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov usuli almashtirildi'**
  String get historyEventPaymentMethodSwitched;

  /// No description provided for @historyEventPriceCorrected.
  ///
  /// In uz, this message translates to:
  /// **'Narx tuzatildi'**
  String get historyEventPriceCorrected;

  /// No description provided for @historyEventShopperAssigned.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi tayinlandi'**
  String get historyEventShopperAssigned;

  /// No description provided for @historyEventShopperReassigned.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi almashtirildi'**
  String get historyEventShopperReassigned;

  /// No description provided for @historyEventCourierAssigned.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer tayinlandi'**
  String get historyEventCourierAssigned;

  /// No description provided for @historyEventCourierReassigned.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer almashtirildi'**
  String get historyEventCourierReassigned;

  /// No description provided for @historyEventDeliveryFailed.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazib bo\'lmadi'**
  String get historyEventDeliveryFailed;

  /// No description provided for @historyEventApprovalRequested.
  ///
  /// In uz, this message translates to:
  /// **'Mijozdan tasdiq so\'raldi'**
  String get historyEventApprovalRequested;

  /// No description provided for @historyEventApprovalDecided.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz javob berdi'**
  String get historyEventApprovalDecided;

  /// No description provided for @historyEventApprovalExpired.
  ///
  /// In uz, this message translates to:
  /// **'Javob muddati o\'tdi'**
  String get historyEventApprovalExpired;

  /// No description provided for @historyEventApprovalResolved.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiq yopildi'**
  String get historyEventApprovalResolved;

  /// No description provided for @historyEventShopperAccepted.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi buyurtmani qabul qildi'**
  String get historyEventShopperAccepted;

  /// No description provided for @historyEventCourierAccepted.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer buyurtmani qabul qildi'**
  String get historyEventCourierAccepted;

  /// No description provided for @historyEventItemPurchased.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot sotib olindi'**
  String get historyEventItemPurchased;

  /// No description provided for @historyEventItemUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot topilmadi'**
  String get historyEventItemUnavailable;

  /// No description provided for @historyEventItemSubstituted.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot almashtirildi'**
  String get historyEventItemSubstituted;

  /// No description provided for @historyEventCancellationRequested.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz bekor qilishni so\'radi'**
  String get historyEventCancellationRequested;

  /// No description provided for @historyEventCancellationRequestDecided.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish so\'rovi ko\'rib chiqildi'**
  String get historyEventCancellationRequestDecided;

  /// No description provided for @historyEventPaymentRecorded.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov qabul qilindi'**
  String get historyEventPaymentRecorded;

  /// No description provided for @historyDeliveryWishChanged.
  ///
  /// In uz, this message translates to:
  /// **'yetkazish istagi o\'zgardi'**
  String get historyDeliveryWishChanged;

  /// No description provided for @historyAssignedTo.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi: {name}'**
  String historyAssignedTo(String name);

  /// No description provided for @historyEditAdded.
  ///
  /// In uz, this message translates to:
  /// **'qo\'shildi: {count}'**
  String historyEditAdded(int count);

  /// No description provided for @historyEditRemoved.
  ///
  /// In uz, this message translates to:
  /// **'olib tashlandi: {count}'**
  String historyEditRemoved(int count);

  /// No description provided for @historyEditChanged.
  ///
  /// In uz, this message translates to:
  /// **'o\'zgartirildi: {count}'**
  String historyEditChanged(int count);

  /// No description provided for @historyReassignedTo.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi: {previous} → {name}'**
  String historyReassignedTo(String previous, String name);

  /// No description provided for @boardFilteredShopper.
  ///
  /// In uz, this message translates to:
  /// **'Tanlangan yig\'uvchi'**
  String get boardFilteredShopper;

  /// No description provided for @boardFilterShopper.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi'**
  String get boardFilterShopper;

  /// No description provided for @errorOrderStateConflict.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma allaqachon o\'zgargan va yangilandi. Uni ko\'rib chiqib, qayta urinib ko\'ring'**
  String get errorOrderStateConflict;

  /// No description provided for @errorStaffNotActive.
  ///
  /// In uz, this message translates to:
  /// **'Bu xodim bloklangan. Boshqasini tanlang'**
  String get errorStaffNotActive;

  /// No description provided for @assignShopper.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi tayinlash'**
  String get assignShopper;

  /// No description provided for @reassignShopper.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchini almashtirish'**
  String get reassignShopper;

  /// No description provided for @pickShopperTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchini tanlang'**
  String get pickShopperTitle;

  /// No description provided for @pickShopperEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Faol yig\'uvchilar yo\'q'**
  String get pickShopperEmpty;

  /// No description provided for @shopperOrdersNow.
  ///
  /// In uz, this message translates to:
  /// **'Hozir {count} ta buyurtma'**
  String shopperOrdersNow(int count);

  /// No description provided for @assigningShopper.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi tayinlanmoqda'**
  String get assigningShopper;

  /// No description provided for @cartTitle.
  ///
  /// In uz, this message translates to:
  /// **'Savat'**
  String get cartTitle;

  /// No description provided for @cartOpen.
  ///
  /// In uz, this message translates to:
  /// **'Savatni ochish'**
  String get cartOpen;

  /// No description provided for @cartBadge.
  ///
  /// In uz, this message translates to:
  /// **'Savat: {count}'**
  String cartBadge(int count);

  /// No description provided for @cartAdded.
  ///
  /// In uz, this message translates to:
  /// **'Savatga qo\'shildi'**
  String get cartAdded;

  /// No description provided for @cartQuantity.
  ///
  /// In uz, this message translates to:
  /// **'Miqdori'**
  String get cartQuantity;

  /// No description provided for @cartQuantityFraction.
  ///
  /// In uz, this message translates to:
  /// **'0 dan katta son: ko\'pi bilan 4 xona va 3 kasr'**
  String get cartQuantityFraction;

  /// No description provided for @cartQuantityWhole.
  ///
  /// In uz, this message translates to:
  /// **'1 dan 9999 gacha butun son'**
  String get cartQuantityWhole;

  /// No description provided for @cartDecrease.
  ///
  /// In uz, this message translates to:
  /// **'Kamaytirish'**
  String get cartDecrease;

  /// No description provided for @cartIncrease.
  ///
  /// In uz, this message translates to:
  /// **'Ko\'paytirish'**
  String get cartIncrease;

  /// No description provided for @cartNote.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi uchun izoh'**
  String get cartNote;

  /// No description provided for @cartSubstitution.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot bo\'lmasa'**
  String get cartSubstitution;

  /// No description provided for @cartLineEstimate.
  ///
  /// In uz, this message translates to:
  /// **'≈ {amount}'**
  String cartLineEstimate(String amount);

  /// No description provided for @cartLineUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Hozir sotuvda yo\'q'**
  String get cartLineUnavailable;

  /// No description provided for @cartUnavailableHint.
  ///
  /// In uz, this message translates to:
  /// **'Sotuvda yo\'q mahsulotlarni olib tashlang — ular bilan buyurtma berib bo\'lmaydi'**
  String get cartUnavailableHint;

  /// No description provided for @cartSaving.
  ///
  /// In uz, this message translates to:
  /// **'Saqlanmoqda'**
  String get cartSaving;

  /// No description provided for @errorCartItemAlreadyExists.
  ///
  /// In uz, this message translates to:
  /// **'Bu mahsulot allaqachon savatda'**
  String get errorCartItemAlreadyExists;

  /// No description provided for @errorCartFull.
  ///
  /// In uz, this message translates to:
  /// **'Savatda ko\'pi bilan 100 ta mahsulot bo\'lishi mumkin'**
  String get errorCartFull;

  /// No description provided for @errorProductUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Bu mahsulot hozir sotuvda yo\'q'**
  String get errorProductUnavailable;

  /// No description provided for @checkoutTitle.
  ///
  /// In uz, this message translates to:
  /// **'Rasmiylashtirish'**
  String get checkoutTitle;

  /// No description provided for @checkoutGo.
  ///
  /// In uz, this message translates to:
  /// **'Rasmiylashtirish'**
  String get checkoutGo;

  /// No description provided for @checkoutPayment.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov usuli'**
  String get checkoutPayment;

  /// No description provided for @checkoutOnlineUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha faqat naqd pul bilan to\'lash mumkin'**
  String get checkoutOnlineUnavailable;

  /// No description provided for @checkoutCalculating.
  ///
  /// In uz, this message translates to:
  /// **'Hisoblanmoqda'**
  String get checkoutCalculating;

  /// No description provided for @checkoutPlacing.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma yuborilmoqda'**
  String get checkoutPlacing;

  /// No description provided for @checkoutPlaced.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma № {number} rasmiylashtirildi'**
  String checkoutPlaced(String number);

  /// No description provided for @checkoutOpenProfile.
  ///
  /// In uz, this message translates to:
  /// **'Ismni kiritish'**
  String get checkoutOpenProfile;

  /// No description provided for @checkoutBackToCart.
  ///
  /// In uz, this message translates to:
  /// **'Savatga qaytish'**
  String get checkoutBackToCart;

  /// No description provided for @errorProfileIncomplete.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma berish uchun profilga ismingizni kiriting'**
  String get errorProfileIncomplete;

  /// No description provided for @errorAddressIncomplete.
  ///
  /// In uz, this message translates to:
  /// **'Manzil to\'liq emas: ko\'cha va uyni kiriting'**
  String get errorAddressIncomplete;

  /// No description provided for @errorAddressGone.
  ///
  /// In uz, this message translates to:
  /// **'Bu manzil topilmadi. Boshqasini tanlang'**
  String get errorAddressGone;

  /// No description provided for @errorCartEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Savat bo\'sh'**
  String get errorCartEmpty;

  /// No description provided for @errorCheckoutProductsUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Ba\'zi mahsulotlarni hozir buyurtma qilib bo\'lmaydi: savatda ularni olib tashlang yoki miqdorini to\'g\'rilang'**
  String get errorCheckoutProductsUnavailable;

  /// No description provided for @errorMinimumOrder.
  ///
  /// In uz, this message translates to:
  /// **'Eng kam buyurtma — {minimum}. Yana {shortfall}lik mahsulot qo\'shing'**
  String errorMinimumOrder(String minimum, String shortfall);

  /// No description provided for @errorMinimumOrderPlain.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma summasi eng kam miqdordan past'**
  String get errorMinimumOrderPlain;

  /// No description provided for @errorPaymentMethodUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Bu to\'lov usuli hozir mavjud emas'**
  String get errorPaymentMethodUnavailable;

  /// No description provided for @errorCheckoutStale.
  ///
  /// In uz, this message translates to:
  /// **'Hisob eskirgan edi va yangilandi. Ko\'rib chiqib, qayta tasdiqlang'**
  String get errorCheckoutStale;

  /// No description provided for @errorOrderInProgress.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma hali yuborilmoqda. Biroz kutib, qayta tasdiqlang'**
  String get errorOrderInProgress;

  /// No description provided for @checkoutUnconfirmed.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma qabul qilingani aniqlanmadi. «Buyurtma berish»ni yana bosing — u ikki marta qabul qilinmaydi'**
  String get checkoutUnconfirmed;

  /// No description provided for @cartUnconfirmedOrder.
  ///
  /// In uz, this message translates to:
  /// **'Oxirgi buyurtmangiz qabul qilingani aniqlanmadi'**
  String get cartUnconfirmedOrder;

  /// No description provided for @cartCheckUnconfirmed.
  ///
  /// In uz, this message translates to:
  /// **'Tekshirish'**
  String get cartCheckUnconfirmed;

  /// No description provided for @errorInProgress.
  ///
  /// In uz, this message translates to:
  /// **'So\'rov hali bajarilmoqda. Biroz kutib, qayta urinib ko\'ring'**
  String get errorInProgress;

  /// No description provided for @checkoutPlacedCancelled.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma №{number} bekor qilingan'**
  String checkoutPlacedCancelled(String number);

  /// No description provided for @checkoutWhere.
  ///
  /// In uz, this message translates to:
  /// **'Qayerga yetkazamiz'**
  String get checkoutWhere;

  /// No description provided for @checkoutWishLabel.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazib berish bo\'yicha istak'**
  String get checkoutWishLabel;

  /// No description provided for @checkoutWishHint.
  ///
  /// In uz, this message translates to:
  /// **'Masalan: 18:00 dan keyin, oldindan qo\'ng\'iroq qiling'**
  String get checkoutWishHint;

  /// No description provided for @paymentCashTitle.
  ///
  /// In uz, this message translates to:
  /// **'Kuryerga naqd pul'**
  String get paymentCashTitle;

  /// No description provided for @paymentCashHint.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilganda, aniq summani yig\'ishdan keyin ko\'rsatamiz'**
  String get paymentCashHint;

  /// No description provided for @paymentOnlineTitle.
  ///
  /// In uz, this message translates to:
  /// **'Onlayn: Payme yoki Click'**
  String get paymentOnlineTitle;

  /// No description provided for @checkoutSoon.
  ///
  /// In uz, this message translates to:
  /// **'Tez orada'**
  String get checkoutSoon;

  /// No description provided for @checkoutItems.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlar · {count}'**
  String checkoutItems(int count);

  /// No description provided for @checkoutOrder.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma berish'**
  String get checkoutOrder;

  /// No description provided for @checkoutClosedBanner.
  ///
  /// In uz, this message translates to:
  /// **'Hozir biz yopiqmiz. Buyurtmani hozir qabul qilamiz, yig\'ib, soat {time} da ochilgandan keyin yetkazib beramiz.'**
  String checkoutClosedBanner(String time);

  /// No description provided for @checkoutRecounted.
  ///
  /// In uz, this message translates to:
  /// **'Rasmiylashtirayotganingizda buyurtma qayta hisoblandi. Summani tekshiring va «Buyurtma berish»ni yana bosing.'**
  String get checkoutRecounted;

  /// No description provided for @checkoutGoneTitle.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, one{Mahsulot tugadi} other{Mahsulotlar tugadi}}'**
  String checkoutGoneTitle(int count);

  /// No description provided for @checkoutGoneText.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, one{Rasmiylashtirayotganingizda bozorda mahsulot tugadi:} other{Rasmiylashtirayotganingizda bozorda mahsulotlar tugadi:}}'**
  String checkoutGoneText(int count);

  /// No description provided for @checkoutGoneHint.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, one{Uni savatdan olib tashlang — qolganini odatdagidek rasmiylashtiramiz.} other{Ularni savatdan olib tashlang — qolganini odatdagidek rasmiylashtiramiz.}}'**
  String checkoutGoneHint(int count);

  /// No description provided for @checkoutGoneAction.
  ///
  /// In uz, this message translates to:
  /// **'Savatga'**
  String get checkoutGoneAction;

  /// No description provided for @checkoutPlacedCash.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi hammasini bozordan sotib oladi. Aniq summani yig\'ishdan keyin buyurtmada ko\'rsatamiz — uni kuryerga naqd berasiz.'**
  String get checkoutPlacedCash;

  /// No description provided for @checkoutPlacedCashFinal.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi hammasini bozordan sotib oladi. Kuryerga naqd to\'lanadi: {amount}.'**
  String checkoutPlacedCashFinal(String amount);

  /// No description provided for @checkoutPlacedOpensAt.
  ///
  /// In uz, this message translates to:
  /// **'Ochilgandan keyin — soat {time} da yig\'ishni boshlaymiz.'**
  String checkoutPlacedOpensAt(String time);

  /// No description provided for @checkoutOrderStatus.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma holati'**
  String get checkoutOrderStatus;

  /// No description provided for @checkoutToHome.
  ///
  /// In uz, this message translates to:
  /// **'Bosh sahifaga'**
  String get checkoutToHome;

  /// No description provided for @myOrders.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalarim'**
  String get myOrders;

  /// No description provided for @myOrdersEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hali buyurtma yo\'q'**
  String get myOrdersEmpty;

  /// No description provided for @customerStatusNew.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilindi'**
  String get customerStatusNew;

  /// No description provided for @customerStatusShoppingAssigned.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi tayinlandi'**
  String get customerStatusShoppingAssigned;

  /// No description provided for @customerStatusShopping.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'ilmoqda'**
  String get customerStatusShopping;

  /// No description provided for @customerStatusFinalPaymentPending.
  ///
  /// In uz, this message translates to:
  /// **'To\'lovni kutmoqda'**
  String get customerStatusFinalPaymentPending;

  /// No description provided for @customerStatusReadyForDelivery.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazishga tayyor'**
  String get customerStatusReadyForDelivery;

  /// No description provided for @customerStatusDeliveryAssigned.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer tayinlandi'**
  String get customerStatusDeliveryAssigned;

  /// No description provided for @customerStatusOnTheWay.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'lda'**
  String get customerStatusOnTheWay;

  /// No description provided for @customerStatusCompleted.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazildi'**
  String get customerStatusCompleted;

  /// No description provided for @customerStatusCancelled.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilindi'**
  String get customerStatusCancelled;

  /// No description provided for @orderEdit.
  ///
  /// In uz, this message translates to:
  /// **'O\'zgartirish'**
  String get orderEdit;

  /// No description provided for @orderEditKitTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma № {number} ni o\'zgartirish'**
  String orderEditKitTitle(int number);

  /// No description provided for @orderEditInfo.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi xarid qilishni boshlamaguncha o\'zgartirish mumkin. Buyurtmadagi mahsulotlarning narxi o\'zgarmaydi.'**
  String get orderEditInfo;

  /// No description provided for @orderEditNew.
  ///
  /// In uz, this message translates to:
  /// **'Yangi'**
  String get orderEditNew;

  /// No description provided for @orderEditRecount.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazish, yig\'im va jamini saqlagandan keyin qayta hisoblaymiz'**
  String get orderEditRecount;

  /// No description provided for @orderPickInOrder.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmada'**
  String get orderPickInOrder;

  /// No description provided for @orderEditRemoveLine.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmadan olib tashlash'**
  String get orderEditRemoveLine;

  /// No description provided for @orderEditKeepLine.
  ///
  /// In uz, this message translates to:
  /// **'Qaytarish'**
  String get orderEditKeepLine;

  /// No description provided for @orderEditAtLeastOne.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmada kamida bitta mahsulot qolishi kerak'**
  String get orderEditAtLeastOne;

  /// No description provided for @orderEditSaving.
  ///
  /// In uz, this message translates to:
  /// **'Saqlanmoqda'**
  String get orderEditSaving;

  /// No description provided for @orderEditClosed.
  ///
  /// In uz, this message translates to:
  /// **'Bu buyurtmani endi o\'zgartirib bo\'lmaydi'**
  String get orderEditClosed;

  /// No description provided for @orderAddProduct.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot qo\'shish'**
  String get orderAddProduct;

  /// No description provided for @orderAddTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmaga qo\'shish'**
  String get orderAddTitle;

  /// No description provided for @orderAddAlreadyIn.
  ///
  /// In uz, this message translates to:
  /// **'Bu mahsulot buyurtmada bor, uni o\'zgartirishingiz mumkin'**
  String get orderAddAlreadyIn;

  /// No description provided for @orderAddFull.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmada ko\'pi bilan {count} ta mahsulot bo\'lishi mumkin'**
  String orderAddFull(int count);

  /// No description provided for @orderCancelReason.
  ///
  /// In uz, this message translates to:
  /// **'Sabab (ixtiyoriy)'**
  String get orderCancelReason;

  /// No description provided for @orderCancelRepeating.
  ///
  /// In uz, this message translates to:
  /// **'Avvalgi so\'rov javobsiz qoldi: u shu sabab bilan qayta yuboriladi'**
  String get orderCancelRepeating;

  /// No description provided for @orderCancelling.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilinmoqda'**
  String get orderCancelling;

  /// No description provided for @orderCancellationNeedsReason.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma allaqachon bajarilmoqda: bekor qilish sababini yozing, operator hal qiladi'**
  String get orderCancellationNeedsReason;

  /// No description provided for @orderOpen.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmani ochish'**
  String get orderOpen;

  /// No description provided for @errorOrderEditingLocked.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmani endi o\'zgartirib bo\'lmaydi. Buyurtma yangilandi'**
  String get errorOrderEditingLocked;

  /// No description provided for @errorOrderCancellationNotAllowed.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmani endi bekor qilib bo\'lmaydi. Buyurtma yangilandi'**
  String get errorOrderCancellationNotAllowed;

  /// No description provided for @boardColumnPeople.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi va kuryer'**
  String get boardColumnPeople;

  /// No description provided for @boardCourierNamed.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer: {name}'**
  String boardCourierNamed(String name);

  /// No description provided for @boardFilterCourier.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer'**
  String get boardFilterCourier;

  /// No description provided for @boardAllCouriers.
  ///
  /// In uz, this message translates to:
  /// **'Barcha kuryerlar'**
  String get boardAllCouriers;

  /// No description provided for @boardFilteredCourier.
  ///
  /// In uz, this message translates to:
  /// **'Tanlangan kuryer'**
  String get boardFilteredCourier;

  /// No description provided for @boardAwaitingCustomerOnly.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz javobini kutayotganlar'**
  String get boardAwaitingCustomerOnly;

  /// No description provided for @boardPendingQuestions.
  ///
  /// In uz, this message translates to:
  /// **'Mijozga {count} ta savol'**
  String boardPendingQuestions(int count);

  /// No description provided for @attentionShowAll.
  ///
  /// In uz, this message translates to:
  /// **'Hammasini ko\'rsatish ({count})'**
  String attentionShowAll(int count);

  /// No description provided for @attentionShowFewer.
  ///
  /// In uz, this message translates to:
  /// **'Kamroq ko\'rsatish'**
  String get attentionShowFewer;

  /// No description provided for @orderSectionCouriers.
  ///
  /// In uz, this message translates to:
  /// **'Kuryerlar'**
  String get orderSectionCouriers;

  /// No description provided for @assignCourier.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer tayinlash'**
  String get assignCourier;

  /// No description provided for @reassignCourier.
  ///
  /// In uz, this message translates to:
  /// **'Kuryerni almashtirish'**
  String get reassignCourier;

  /// No description provided for @assigningCourier.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer tayinlanmoqda'**
  String get assigningCourier;

  /// No description provided for @pickCourierTitle.
  ///
  /// In uz, this message translates to:
  /// **'Kuryerni tanlang'**
  String get pickCourierTitle;

  /// No description provided for @pickCourierEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Faol kuryerlar yo\'q'**
  String get pickCourierEmpty;

  /// No description provided for @courierStarted.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'lga chiqdi: {time}'**
  String courierStarted(String time);

  /// No description provided for @courierEndCompleted.
  ///
  /// In uz, this message translates to:
  /// **'yetkazildi'**
  String get courierEndCompleted;

  /// No description provided for @courierEndReassigned.
  ///
  /// In uz, this message translates to:
  /// **'boshqa kuryerga o\'tkazildi'**
  String get courierEndReassigned;

  /// No description provided for @courierEndDeliveryFailed.
  ///
  /// In uz, this message translates to:
  /// **'yetkazilmadi'**
  String get courierEndDeliveryFailed;

  /// No description provided for @deliveryFailureNoAnswer.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz javob bermadi'**
  String get deliveryFailureNoAnswer;

  /// No description provided for @deliveryFailureRefused.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz qabul qilmadi'**
  String get deliveryFailureRefused;

  /// No description provided for @deliveryFailureWrongAddress.
  ///
  /// In uz, this message translates to:
  /// **'Manzil noto\'g\'ri'**
  String get deliveryFailureWrongAddress;

  /// No description provided for @deliveryFailureOther.
  ///
  /// In uz, this message translates to:
  /// **'Boshqa sabab'**
  String get deliveryFailureOther;

  /// No description provided for @staffBlockCurrentOrders.
  ///
  /// In uz, this message translates to:
  /// **'Hozir xodimda {count} ta buyurtma bor. Boshlangan yig\'ish yoki yo\'ldagi yetkazish boshqa xodimga o\'tmaydi.'**
  String staffBlockCurrentOrders(int count);

  /// No description provided for @courierAssignmentsNone.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer hali tayinlanmagan'**
  String get courierAssignmentsNone;

  /// No description provided for @historyCourierAssignedTo.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer: {name}'**
  String historyCourierAssignedTo(String name);

  /// No description provided for @historyCourierReassignedTo.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer: {previous} → {name}'**
  String historyCourierReassignedTo(String previous, String name);

  /// No description provided for @staffBlockOrdersLoading.
  ///
  /// In uz, this message translates to:
  /// **'Xodimdagi buyurtmalar soni yuklanmoqda…'**
  String get staffBlockOrdersLoading;

  /// No description provided for @staffBlockOrdersUnknown.
  ///
  /// In uz, this message translates to:
  /// **'Xodimdagi buyurtmalar sonini bilib bo\'lmadi. Boshlangan yig\'ish yoki yo\'ldagi yetkazish boshqa xodimga o\'tmaydi.'**
  String get staffBlockOrdersUnknown;

  /// No description provided for @orderSectionApprovals.
  ///
  /// In uz, this message translates to:
  /// **'Mijozga savollar'**
  String get orderSectionApprovals;

  /// No description provided for @orderSectionCancellationRequests.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish so\'rovlari'**
  String get orderSectionCancellationRequests;

  /// No description provided for @orderSectionPayment.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov'**
  String get orderSectionPayment;

  /// No description provided for @itemBought.
  ///
  /// In uz, this message translates to:
  /// **'Sotib olindi: {quantity}'**
  String itemBought(String quantity);

  /// No description provided for @itemBilled.
  ///
  /// In uz, this message translates to:
  /// **'Hisobga: {quantity}'**
  String itemBilled(String quantity);

  /// No description provided for @itemPricePaid.
  ///
  /// In uz, this message translates to:
  /// **'Sotib olish narxi: {price}'**
  String itemPricePaid(String price);

  /// No description provided for @itemWasEstimate.
  ///
  /// In uz, this message translates to:
  /// **'avval ≈ {price}'**
  String itemWasEstimate(String price);

  /// No description provided for @itemBilledPrice.
  ///
  /// In uz, this message translates to:
  /// **'Mijozga narx: {price}'**
  String itemBilledPrice(String price);

  /// No description provided for @itemReplacedWith.
  ///
  /// In uz, this message translates to:
  /// **'O\'rniga: {name}'**
  String itemReplacedWith(String name);

  /// No description provided for @replacementAutomatic.
  ///
  /// In uz, this message translates to:
  /// **'avtomatik'**
  String get replacementAutomatic;

  /// No description provided for @replacementApproved.
  ///
  /// In uz, this message translates to:
  /// **'mijoz rozi bo\'ldi'**
  String get replacementApproved;

  /// No description provided for @approvalsNone.
  ///
  /// In uz, this message translates to:
  /// **'Mijozga savol berilmagan'**
  String get approvalsNone;

  /// No description provided for @approvalTypePrice.
  ///
  /// In uz, this message translates to:
  /// **'Narx chegaradan yuqori'**
  String get approvalTypePrice;

  /// No description provided for @approvalTypeSubstitution.
  ///
  /// In uz, this message translates to:
  /// **'Almashtirish'**
  String get approvalTypeSubstitution;

  /// No description provided for @approvalTypeReducedQuantity.
  ///
  /// In uz, this message translates to:
  /// **'Kamroq miqdor'**
  String get approvalTypeReducedQuantity;

  /// No description provided for @approvalStatusPending.
  ///
  /// In uz, this message translates to:
  /// **'Javob kutilmoqda'**
  String get approvalStatusPending;

  /// No description provided for @approvalStatusApproved.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz rozi bo\'ldi'**
  String get approvalStatusApproved;

  /// No description provided for @approvalStatusRejected.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz rad etdi'**
  String get approvalStatusRejected;

  /// No description provided for @approvalStatusExpired.
  ///
  /// In uz, this message translates to:
  /// **'Muddati o\'tdi'**
  String get approvalStatusExpired;

  /// No description provided for @approvalStatusCancelled.
  ///
  /// In uz, this message translates to:
  /// **'Yopildi'**
  String get approvalStatusCancelled;

  /// No description provided for @approvalProposedPrice.
  ///
  /// In uz, this message translates to:
  /// **'Taklif: {price}, sotib olish narxi {paid}'**
  String approvalProposedPrice(String price, String paid);

  /// No description provided for @approvalProposedQuantity.
  ///
  /// In uz, this message translates to:
  /// **'Taklif: {quantity}'**
  String approvalProposedQuantity(String quantity);

  /// No description provided for @approvalReplacement.
  ///
  /// In uz, this message translates to:
  /// **'O\'rniga: {name}'**
  String approvalReplacement(String name);

  /// No description provided for @approvalAskedBy.
  ///
  /// In uz, this message translates to:
  /// **'{name} so\'radi, {time}'**
  String approvalAskedBy(String name, String time);

  /// No description provided for @approvalTimers.
  ///
  /// In uz, this message translates to:
  /// **'Diqqat: {attention} · Muddat: {expires}'**
  String approvalTimers(String attention, String expires);

  /// No description provided for @approvalResolvedBy.
  ///
  /// In uz, this message translates to:
  /// **'Hal qildi: {name}, {time}'**
  String approvalResolvedBy(String name, String time);

  /// No description provided for @approvalClosedAt.
  ///
  /// In uz, this message translates to:
  /// **'Yopildi: {time}'**
  String approvalClosedAt(String time);

  /// No description provided for @approvalLineRemoved.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot buyurtmadan olib tashlandi'**
  String get approvalLineRemoved;

  /// No description provided for @removeExpiredLine.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotni olib tashlash'**
  String get removeExpiredLine;

  /// No description provided for @removeExpiredTitle.
  ///
  /// In uz, this message translates to:
  /// **'«{name}»ni olib tashlaysizmi?'**
  String removeExpiredTitle(String name);

  /// No description provided for @removeExpiredExplained.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz o\'z vaqtida javob bermadi. Mahsulot buyurtmadan olib tashlanadi; sotib olinadigan boshqa narsa qolmasa, buyurtma bekor qilinadi.'**
  String get removeExpiredExplained;

  /// No description provided for @requestStatusPending.
  ///
  /// In uz, this message translates to:
  /// **'Qaror kutilmoqda'**
  String get requestStatusPending;

  /// No description provided for @requestStatusApproved.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlandi'**
  String get requestStatusApproved;

  /// No description provided for @requestStatusRejected.
  ///
  /// In uz, this message translates to:
  /// **'Rad etildi'**
  String get requestStatusRejected;

  /// No description provided for @requestStatusClosed.
  ///
  /// In uz, this message translates to:
  /// **'Yopildi'**
  String get requestStatusClosed;

  /// No description provided for @requestOriginCustomer.
  ///
  /// In uz, this message translates to:
  /// **'Mijozdan'**
  String get requestOriginCustomer;

  /// No description provided for @requestOriginStaff.
  ///
  /// In uz, this message translates to:
  /// **'Xodimdan'**
  String get requestOriginStaff;

  /// No description provided for @requestReason.
  ///
  /// In uz, this message translates to:
  /// **'Sabab: {reason}'**
  String requestReason(String reason);

  /// No description provided for @requestFiledBy.
  ///
  /// In uz, this message translates to:
  /// **'{name}, {time}'**
  String requestFiledBy(String name, String time);

  /// No description provided for @requestDecidedBy.
  ///
  /// In uz, this message translates to:
  /// **'Qaror: {name}, {time}'**
  String requestDecidedBy(String name, String time);

  /// No description provided for @requestClosedAt.
  ///
  /// In uz, this message translates to:
  /// **'Yopildi: {time}'**
  String requestClosedAt(String time);

  /// No description provided for @approveRequest.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilishni tasdiqlash'**
  String get approveRequest;

  /// No description provided for @rejectRequest.
  ///
  /// In uz, this message translates to:
  /// **'Rad etish'**
  String get rejectRequest;

  /// No description provided for @approveRequestTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmani bekor qilasizmi?'**
  String get approveRequestTitle;

  /// No description provided for @approveRequestExplained.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma bekor qilinadi: joriy tayinlov tugaydi, ochiq mahsulotlar olib tashlanadi, sotib olingan narsa qoladi va hech narsa to\'lanmaydi.'**
  String get approveRequestExplained;

  /// No description provided for @rejectRequestTitle.
  ///
  /// In uz, this message translates to:
  /// **'So\'rovni rad etasizmi?'**
  String get rejectRequestTitle;

  /// No description provided for @rejectRequestExplained.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma davom etadi.'**
  String get rejectRequestExplained;

  /// No description provided for @cancelFailedDelivery.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmani bekor qilish'**
  String get cancelFailedDelivery;

  /// No description provided for @cancelFailedDeliveryTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmani bekor qilasizmi?'**
  String get cancelFailedDeliveryTitle;

  /// No description provided for @cancelFailedDeliveryExplained.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma «yetkazib bo\'lmadi» sababi bilan bekor qilinadi.'**
  String get cancelFailedDeliveryExplained;

  /// No description provided for @actionNote.
  ///
  /// In uz, this message translates to:
  /// **'Izoh (ixtiyoriy)'**
  String get actionNote;

  /// No description provided for @paymentNone.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov hali qayd etilmagan'**
  String get paymentNone;

  /// No description provided for @paymentStatusUnpaid.
  ///
  /// In uz, this message translates to:
  /// **'To\'lanmagan'**
  String get paymentStatusUnpaid;

  /// No description provided for @paymentStatusPending.
  ///
  /// In uz, this message translates to:
  /// **'Kutilmoqda'**
  String get paymentStatusPending;

  /// No description provided for @paymentStatusPaid.
  ///
  /// In uz, this message translates to:
  /// **'To\'langan'**
  String get paymentStatusPaid;

  /// No description provided for @paymentStatusCancelled.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilingan'**
  String get paymentStatusCancelled;

  /// No description provided for @paymentAmount.
  ///
  /// In uz, this message translates to:
  /// **'Summa: {amount}'**
  String paymentAmount(String amount);

  /// No description provided for @paymentPaidAt.
  ///
  /// In uz, this message translates to:
  /// **'To\'langan vaqti: {time}'**
  String paymentPaidAt(String time);

  /// No description provided for @paymentRecordedBy.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qildi: {name}'**
  String paymentRecordedBy(String name);

  /// No description provided for @correctPrice.
  ///
  /// In uz, this message translates to:
  /// **'Narxni tuzatish'**
  String get correctPrice;

  /// No description provided for @correctPriceTitle.
  ///
  /// In uz, this message translates to:
  /// **'Narxni tuzatish: {name}'**
  String correctPriceTitle(String name);

  /// No description provided for @correctPriceNew.
  ///
  /// In uz, this message translates to:
  /// **'Yangi sotib olish narxi, so\'m'**
  String get correctPriceNew;

  /// No description provided for @correctPriceReason.
  ///
  /// In uz, this message translates to:
  /// **'Sabab'**
  String get correctPriceReason;

  /// No description provided for @errorPriceAboveCeiling.
  ///
  /// In uz, this message translates to:
  /// **'Mijozga narx chegaradan oshadi. Sotib olish narxi mijozga ko\'pi bilan {ceiling} bo\'ladigan qilib kiriting.'**
  String errorPriceAboveCeiling(String ceiling);

  /// No description provided for @errorPriceAboveCeilingPlain.
  ///
  /// In uz, this message translates to:
  /// **'Mijozga narx chegaradan oshadi.'**
  String get errorPriceAboveCeilingPlain;

  /// No description provided for @historyPriceCorrectedDetails.
  ///
  /// In uz, this message translates to:
  /// **'{name}: sotib olish narxi {oldPaid} → {newPaid}, mijozga {oldBilled} → {newBilled}'**
  String historyPriceCorrectedDetails(
    String name,
    String oldPaid,
    String newPaid,
    String oldBilled,
    String newBilled,
  );

  /// No description provided for @errorApprovalNotExpired.
  ///
  /// In uz, this message translates to:
  /// **'Savolning muddati hali o\'tmagan.'**
  String get errorApprovalNotExpired;

  /// No description provided for @errorApprovalAlreadyResolved.
  ///
  /// In uz, this message translates to:
  /// **'Savol allaqachon hal qilingan.'**
  String get errorApprovalAlreadyResolved;

  /// No description provided for @errorRequestAlreadyDecided.
  ///
  /// In uz, this message translates to:
  /// **'So\'rov bo\'yicha qaror allaqachon qabul qilingan.'**
  String get errorRequestAlreadyDecided;

  /// No description provided for @errorCancellationAlreadyPending.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish so\'rovi kutilmoqda — avval u bo\'yicha qaror qabul qiling.'**
  String get errorCancellationAlreadyPending;

  /// No description provided for @errorPriceCorrectionLocked.
  ///
  /// In uz, this message translates to:
  /// **'Narxni endi tuzatib bo\'lmaydi: buyurtma yo\'lda, yakunlangan, bekor qilingan yoki onlayn to\'lanadi.'**
  String get errorPriceCorrectionLocked;

  /// No description provided for @errorPriceCorrectionNotApplicable.
  ///
  /// In uz, this message translates to:
  /// **'Bu mahsulot narxini tuzatib bo\'lmaydi.'**
  String get errorPriceCorrectionNotApplicable;

  /// No description provided for @staffMenu.
  ///
  /// In uz, this message translates to:
  /// **'Menyu'**
  String get staffMenu;

  /// No description provided for @shopperOrdersEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Operator sizga buyurtma tayinlasa, u shu yerda paydo bo\'ladi. Ro\'yxat o\'zi yangilanadi.'**
  String get shopperOrdersEmpty;

  /// No description provided for @shopperChipNew.
  ///
  /// In uz, this message translates to:
  /// **'Yangi'**
  String get shopperChipNew;

  /// No description provided for @shopperChipAccepted.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilindi'**
  String get shopperChipAccepted;

  /// No description provided for @shopperAssigned.
  ///
  /// In uz, this message translates to:
  /// **'Tayinlandi: {when}'**
  String shopperAssigned(String when);

  /// No description provided for @shopperAccepted.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilindi: {when}'**
  String shopperAccepted(String when);

  /// No description provided for @shopperStarted.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'ish boshlandi: {when}'**
  String shopperStarted(String when);

  /// No description provided for @shopperOpenOf.
  ///
  /// In uz, this message translates to:
  /// **'Qoldi: {open} / {total}'**
  String shopperOpenOf(int open, int total);

  /// No description provided for @shopperDeliveryWish.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazish: {wish}'**
  String shopperDeliveryWish(String wish);

  /// No description provided for @shopperOpenToAccept.
  ///
  /// In uz, this message translates to:
  /// **'Oching va buyurtmani qabul qiling'**
  String get shopperOpenToAccept;

  /// No description provided for @shopperStatusNew.
  ///
  /// In uz, this message translates to:
  /// **'Yangi buyurtma'**
  String get shopperStatusNew;

  /// No description provided for @shopperStatusNewHint.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlarni ko\'rib chiqing va buyurtmani qabul qiling'**
  String get shopperStatusNewHint;

  /// No description provided for @shopperStatusAccepted.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma qabul qilindi'**
  String get shopperStatusAccepted;

  /// No description provided for @shopperStatusShopping.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'ish davom etmoqda'**
  String get shopperStatusShopping;

  /// No description provided for @shopperShoppingHint.
  ///
  /// In uz, this message translates to:
  /// **'Boshlandi: {when} · qoldi {open} / {total}'**
  String shopperShoppingHint(String when, int open, int total);

  /// No description provided for @shopperStatusResolved.
  ///
  /// In uz, this message translates to:
  /// **'Hammasi hal qilindi'**
  String get shopperStatusResolved;

  /// No description provided for @shopperResolvedHint.
  ///
  /// In uz, this message translates to:
  /// **'Sotib olindi: {bought} · olib tashlandi: {removed} · yakunlash mumkin'**
  String shopperResolvedHint(int bought, int removed);

  /// No description provided for @shopperStepAssigned.
  ///
  /// In uz, this message translates to:
  /// **'Tayinlandi'**
  String get shopperStepAssigned;

  /// No description provided for @shopperStepAccepted.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilindi'**
  String get shopperStepAccepted;

  /// No description provided for @shopperStepShopping.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'ish'**
  String get shopperStepShopping;

  /// No description provided for @shopperStepDone.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'ildi'**
  String get shopperStepDone;

  /// No description provided for @shopperLegendDone.
  ///
  /// In uz, this message translates to:
  /// **'Tayyor: {count}'**
  String shopperLegendDone(int count);

  /// No description provided for @shopperLegendWaiting.
  ///
  /// In uz, this message translates to:
  /// **'Javob kutilmoqda: {count}'**
  String shopperLegendWaiting(int count);

  /// No description provided for @shopperLegendToBuy.
  ///
  /// In uz, this message translates to:
  /// **'Sotib olish: {count}'**
  String shopperLegendToBuy(int count);

  /// No description provided for @shopperCallCustomer.
  ///
  /// In uz, this message translates to:
  /// **'Mijozga qo\'ng\'iroq qilish'**
  String get shopperCallCustomer;

  /// No description provided for @shopperPhoneLater.
  ///
  /// In uz, this message translates to:
  /// **'Mijozning telefoni yig\'ishni boshlaganingizda ko\'rinadi.'**
  String get shopperPhoneLater;

  /// No description provided for @shopperResolveFirst.
  ///
  /// In uz, this message translates to:
  /// **'Avval barcha mahsulotlarni hal qiling · qoldi: {count}'**
  String shopperResolveFirst(int count);

  /// No description provided for @shopperCompleteBought.
  ///
  /// In uz, this message translates to:
  /// **'Sotib olindi'**
  String get shopperCompleteBought;

  /// No description provided for @shopperCompleteRemoved.
  ///
  /// In uz, this message translates to:
  /// **'Olib tashlandi'**
  String get shopperCompleteRemoved;

  /// No description provided for @completeConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Yakunlash'**
  String get completeConfirm;

  /// No description provided for @shopperOrderGoneHint.
  ///
  /// In uz, this message translates to:
  /// **'U bekor qilingan yoki boshqa yig\'uvchiga berilgan.'**
  String get shopperOrderGoneHint;

  /// No description provided for @shopperStartAtMarket.
  ///
  /// In uz, this message translates to:
  /// **'Bozorga yetganingizda yig\'ishni boshlang'**
  String get shopperStartAtMarket;

  /// No description provided for @shopperEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha buyurtma yo\'q'**
  String get shopperEmptyTitle;

  /// No description provided for @staffCustomerModeHint.
  ///
  /// In uz, this message translates to:
  /// **'O\'zingiz uchun mahsulot buyurtma qilish'**
  String get staffCustomerModeHint;

  /// No description provided for @shopperAccept.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmani qabul qilish'**
  String get shopperAccept;

  /// No description provided for @shopperStart.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'ishni boshlash'**
  String get shopperStart;

  /// No description provided for @callFailed.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'ng\'iroq ilovasi ochilmadi. Raqamni qo\'lda tering: {phone}'**
  String callFailed(String phone);

  /// No description provided for @shopperPageEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Bu sahifada buyurtma qolmadi. Oldingi sahifaga o\'ting.'**
  String get shopperPageEmpty;

  /// No description provided for @lineBuy.
  ///
  /// In uz, this message translates to:
  /// **'Sotib olish'**
  String get lineBuy;

  /// No description provided for @lineReplace.
  ///
  /// In uz, this message translates to:
  /// **'Almashtirish'**
  String get lineReplace;

  /// No description provided for @lineUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Topilmadi'**
  String get lineUnavailable;

  /// No description provided for @purchaseSheetTitle.
  ///
  /// In uz, this message translates to:
  /// **'Xarid'**
  String get purchaseSheetTitle;

  /// No description provided for @purchaseNeeded.
  ///
  /// In uz, this message translates to:
  /// **'Mijozga {quantity} kerak'**
  String purchaseNeeded(String quantity);

  /// No description provided for @purchaseQuantity.
  ///
  /// In uz, this message translates to:
  /// **'Sotib olingan miqdor'**
  String get purchaseQuantity;

  /// No description provided for @purchasePriceFor.
  ///
  /// In uz, this message translates to:
  /// **'1 {unit} narxi (to\'langan)'**
  String purchasePriceFor(String unit);

  /// No description provided for @purchasePriceShort.
  ///
  /// In uz, this message translates to:
  /// **'1 {unit} narxi'**
  String purchasePriceShort(String unit);

  /// No description provided for @purchaseExcess.
  ///
  /// In uz, this message translates to:
  /// **'{quantity} dan ortig\'ini mijoz to\'lamaydi.'**
  String purchaseExcess(String quantity);

  /// No description provided for @purchaseMarketInfo.
  ///
  /// In uz, this message translates to:
  /// **'Bozor narxi {price}. Mijozdan so\'ramasdan — 1 {unit} uchun {bound} gacha.'**
  String purchaseMarketInfo(String price, String bound, String unit);

  /// No description provided for @purchaseMarketOnly.
  ///
  /// In uz, this message translates to:
  /// **'Bozor narxi {price}.'**
  String purchaseMarketOnly(String price);

  /// No description provided for @purchaseWhich.
  ///
  /// In uz, this message translates to:
  /// **'Almashtiruvchini oldingizmi yoki «{name}» topildimi? Nima olganingizni tanlang.'**
  String purchaseWhich(String name);

  /// No description provided for @purchasePriceOptional.
  ///
  /// In uz, this message translates to:
  /// **'Narxi belgilangan mahsulot: narx ixtiyoriy'**
  String get purchasePriceOptional;

  /// No description provided for @purchaseSave.
  ///
  /// In uz, this message translates to:
  /// **'Sotib oldim'**
  String get purchaseSave;

  /// No description provided for @purchaseAgain.
  ///
  /// In uz, this message translates to:
  /// **'Qayta yuborish'**
  String get purchaseAgain;

  /// No description provided for @purchaseUnconfirmed.
  ///
  /// In uz, this message translates to:
  /// **'Oxirgi xaridga javob kelmadi. «Sotib olish»ni bosing — o\'sha xarid qayta yuboriladi.'**
  String get purchaseUnconfirmed;

  /// No description provided for @purchaseAboveBound.
  ///
  /// In uz, this message translates to:
  /// **'Bu mijozdan so\'ramasdan mumkin bo\'lganidan qimmat ({bound} gacha). Mijozdan so\'rang yoki arzonroq toping.'**
  String purchaseAboveBound(String bound);

  /// No description provided for @purchaseBelowQuantity.
  ///
  /// In uz, this message translates to:
  /// **'Mijozga {required} kerak. Shuncha sotib oling yoki mijozdan {quantity} ga roziligini so\'rang.'**
  String purchaseBelowQuantity(String required, String quantity);

  /// No description provided for @askNote.
  ///
  /// In uz, this message translates to:
  /// **'Mijozga izoh (ixtiyoriy)'**
  String get askNote;

  /// No description provided for @askCustomer.
  ///
  /// In uz, this message translates to:
  /// **'Mijozdan so\'rash'**
  String get askCustomer;

  /// No description provided for @askNotePlaceholder.
  ///
  /// In uz, this message translates to:
  /// **'Masalan: boshqa yangisi yo\'q'**
  String get askNotePlaceholder;

  /// No description provided for @typoTitle.
  ///
  /// In uz, this message translates to:
  /// **'Narxni tekshiring'**
  String get typoTitle;

  /// No description provided for @typoExplained.
  ///
  /// In uz, this message translates to:
  /// **'Siz {price} kiritdingiz, bozor narxi esa {market}. To\'g\'rimi?'**
  String typoExplained(String price, String market);

  /// No description provided for @typoConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Ha, to\'g\'ri'**
  String get typoConfirm;

  /// No description provided for @typoCancel.
  ///
  /// In uz, this message translates to:
  /// **'Tuzataman'**
  String get typoCancel;

  /// No description provided for @unavailableSheetTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot yo\'qmi?'**
  String get unavailableSheetTitle;

  /// No description provided for @unavailableExplained.
  ///
  /// In uz, this message translates to:
  /// **'«{name}» buyurtmadan olib tashlanadi. Sotib olinadigan boshqa narsa qolmasa, buyurtma bekor qilinadi.'**
  String unavailableExplained(String name);

  /// No description provided for @unavailableNotePlaceholder.
  ///
  /// In uz, this message translates to:
  /// **'Masalan: hammasi so\'lgan'**
  String get unavailableNotePlaceholder;

  /// No description provided for @unavailableConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Ha, topilmadi'**
  String get unavailableConfirm;

  /// No description provided for @replaceTitle.
  ///
  /// In uz, this message translates to:
  /// **'«{name}» o\'rniga'**
  String replaceTitle(String name);

  /// No description provided for @replaceSearchHint.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot nomi'**
  String get replaceSearchHint;

  /// No description provided for @replaceNone.
  ///
  /// In uz, this message translates to:
  /// **'Mos mahsulot topilmadi'**
  String get replaceNone;

  /// No description provided for @replaceInfoSimilar.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz: o\'xshashi bilan almashtirish mumkin. Narx chegarada bo\'lsa — darhol almashtiriladi, aks holda mijozdan so\'raladi.'**
  String get replaceInfoSimilar;

  /// No description provided for @replaceInfoContact.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz almashtirishdan oldin bog\'lanishni so\'ragan — avval unga taklif qilinadi.'**
  String get replaceInfoContact;

  /// No description provided for @replacePricePer.
  ///
  /// In uz, this message translates to:
  /// **'{price} / {unit}'**
  String replacePricePer(String price, String unit);

  /// No description provided for @replaceMarket.
  ///
  /// In uz, this message translates to:
  /// **'bozor narxi'**
  String get replaceMarket;

  /// No description provided for @replaceUnitHint.
  ///
  /// In uz, this message translates to:
  /// **'Bir xil o\'lchov birligidagi mahsulotlar: {unit}'**
  String replaceUnitHint(String unit);

  /// No description provided for @replaceNoneHint.
  ///
  /// In uz, this message translates to:
  /// **'Boshqa nom bilan qidiring. Almashtiradigan narsa bo\'lmasa — orqaga qayting va «Topilmadi»ni bosing.'**
  String get replaceNoneHint;

  /// No description provided for @substituteSheetTitle.
  ///
  /// In uz, this message translates to:
  /// **'Almashtirishni taklif qilish'**
  String get substituteSheetTitle;

  /// No description provided for @substituteInstead.
  ///
  /// In uz, this message translates to:
  /// **'«{name}» o\'rniga, {quantity}'**
  String substituteInstead(String name, String quantity);

  /// No description provided for @substitutePriceFor.
  ///
  /// In uz, this message translates to:
  /// **'1 {unit} narxi (to\'laysiz)'**
  String substitutePriceFor(String unit);

  /// No description provided for @substituteInfoSimilar.
  ///
  /// In uz, this message translates to:
  /// **'Narx chegarada bo\'lsa — darhol oling. Qimmatroq bo\'lsa — mijozga savol boradi.'**
  String get substituteInfoSimilar;

  /// No description provided for @substituteInfoContact.
  ///
  /// In uz, this message translates to:
  /// **'Mijozga almashtirish haqida savol boradi.'**
  String get substituteInfoContact;

  /// No description provided for @doneWriteOnBag.
  ///
  /// In uz, this message translates to:
  /// **'Paketga yozing'**
  String get doneWriteOnBag;

  /// No description provided for @substituteSave.
  ///
  /// In uz, this message translates to:
  /// **'Taklif qilish'**
  String get substituteSave;

  /// No description provided for @completeShopping.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'ishni yakunlash'**
  String get completeShopping;

  /// No description provided for @completeTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'ish yakunlansinmi?'**
  String get completeTitle;

  /// No description provided for @completeExplained.
  ///
  /// In uz, this message translates to:
  /// **'Yakunlangach, buyurtma ro\'yxatingizdan chiqadi va uni yetkazishga tayyorlanadi.'**
  String get completeExplained;

  /// No description provided for @completeUnconfirmed.
  ///
  /// In uz, this message translates to:
  /// **'Oxirgi yakunlashga javob kelmadi — qayta yuboriladi.'**
  String get completeUnconfirmed;

  /// No description provided for @completeIncomplete.
  ///
  /// In uz, this message translates to:
  /// **'Hali hal qilinmagan: {names}'**
  String completeIncomplete(String names);

  /// No description provided for @doneTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma № {number} yig\'ildi'**
  String doneTitle(String number);

  /// No description provided for @doneLabel.
  ///
  /// In uz, this message translates to:
  /// **'Paketni topshirish joyiga olib boring.'**
  String get doneLabel;

  /// No description provided for @doneBack.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalarimga'**
  String get doneBack;

  /// No description provided for @errorShoppingNotActive.
  ///
  /// In uz, this message translates to:
  /// **'Bu buyurtmani hozir yig\'ib bo\'lmaydi.'**
  String get errorShoppingNotActive;

  /// No description provided for @errorItemAlreadyResolved.
  ///
  /// In uz, this message translates to:
  /// **'Bu mahsulot allaqachon hal qilingan.'**
  String get errorItemAlreadyResolved;

  /// No description provided for @errorCustomerApprovalRequired.
  ///
  /// In uz, this message translates to:
  /// **'Buning uchun mijozning roziligi kerak.'**
  String get errorCustomerApprovalRequired;

  /// No description provided for @errorApprovalNotNeeded.
  ///
  /// In uz, this message translates to:
  /// **'Bu narx uchun mijozdan so\'rash shart emas — sotib olavering.'**
  String get errorApprovalNotNeeded;

  /// No description provided for @errorSubstitutionNotAllowed.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz bu mahsulotni almashtirishga rozi emas.'**
  String get errorSubstitutionNotAllowed;

  /// No description provided for @errorShoppingIncomplete.
  ///
  /// In uz, this message translates to:
  /// **'Hali hal qilinmagan mahsulotlar bor.'**
  String get errorShoppingIncomplete;

  /// No description provided for @shopperOrderGone.
  ///
  /// In uz, this message translates to:
  /// **'Bu buyurtma endi sizda emas'**
  String get shopperOrderGone;

  /// No description provided for @shopperOrderCancelled.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma bekor qilindi: sotib olinadigan narsa qolmadi.'**
  String get shopperOrderCancelled;

  /// No description provided for @substituteUseBuy.
  ///
  /// In uz, this message translates to:
  /// **'Bu almashtirish allaqachon tasdiqlangan. Narxni «Sotib olish» orqali kiriting — kerak bo\'lsa, u yerda mijozdan so\'rash taklif qilinadi.'**
  String get substituteUseBuy;

  /// No description provided for @questionReplacementPrice.
  ///
  /// In uz, this message translates to:
  /// **'O\'rniga olinadigan «{name}»: narxi {price}. Shu narxga rozimisiz?'**
  String questionReplacementPrice(String name, String price);

  /// No description provided for @questionSubstitution.
  ///
  /// In uz, this message translates to:
  /// **'{name}: topilmadi. O\'rniga — {replacement}, {price}. Rozimisiz?'**
  String questionSubstitution(String name, String replacement, String price);

  /// No description provided for @questionExpires.
  ///
  /// In uz, this message translates to:
  /// **'Javob berish muddati: {time}gacha'**
  String questionExpires(String time);

  /// No description provided for @questionApprove.
  ///
  /// In uz, this message translates to:
  /// **'Rozi bo\'lish'**
  String get questionApprove;

  /// No description provided for @questionReject.
  ///
  /// In uz, this message translates to:
  /// **'Rad etish'**
  String get questionReject;

  /// No description provided for @questionFromShopper.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchidan savol'**
  String get questionFromShopper;

  /// No description provided for @questionSubstitutionTitle.
  ///
  /// In uz, this message translates to:
  /// **'Almashtirish'**
  String get questionSubstitutionTitle;

  /// No description provided for @questionLessTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmadan kam'**
  String get questionLessTitle;

  /// No description provided for @questionPriceKit.
  ///
  /// In uz, this message translates to:
  /// **'Bugungi narx {price}, buyurtma paytida {was} edi. Shu narxga rozimisiz?'**
  String questionPriceKit(String price, String was);

  /// No description provided for @questionLessKit.
  ///
  /// In uz, this message translates to:
  /// **'Faqat {proposed} bor, siz {ordered} buyurtma qildingiz. Kamiga rozimisiz?'**
  String questionLessKit(String proposed, String ordered);

  /// No description provided for @questionInsteadOf.
  ///
  /// In uz, this message translates to:
  /// **'«{name}» o\'rniga, {quantity}'**
  String questionInsteadOf(String name, String quantity);

  /// No description provided for @questionNoteKit.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi: «{note}»'**
  String questionNoteKit(String note);

  /// No description provided for @questionExpiredTitle.
  ///
  /// In uz, this message translates to:
  /// **'Javob vaqti tugadi'**
  String get questionExpiredTitle;

  /// No description provided for @questionExpiredLine.
  ///
  /// In uz, this message translates to:
  /// **'Bu mahsulot buyurtmadan olib tashlanadi'**
  String get questionExpiredLine;

  /// No description provided for @decisionUnanswered.
  ///
  /// In uz, this message translates to:
  /// **'«{decision}» javobingiz yuborildi, lekin tasdiq kelmadi. Qayta yuborsangiz, xuddi shu javob ketadi.'**
  String decisionUnanswered(String decision);

  /// No description provided for @sendAgain.
  ///
  /// In uz, this message translates to:
  /// **'Qayta yuborish'**
  String get sendAgain;

  /// No description provided for @requestStateApproved.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlandi — buyurtma bekor qilindi'**
  String get requestStateApproved;

  /// No description provided for @requestStateRejected.
  ///
  /// In uz, this message translates to:
  /// **'Operator rad etdi'**
  String get requestStateRejected;

  /// No description provided for @requestStateClosed.
  ///
  /// In uz, this message translates to:
  /// **'Yopildi — buyurtma boshqacha yakunlandi'**
  String get requestStateClosed;

  /// No description provided for @orderRequestCancel.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilishni so\'rash'**
  String get orderRequestCancel;

  /// No description provided for @orderRequestCancelReason.
  ///
  /// In uz, this message translates to:
  /// **'Sabab'**
  String get orderRequestCancelReason;

  /// No description provided for @errorApprovalExpired.
  ///
  /// In uz, this message translates to:
  /// **'Savolga javob berish vaqti o\'tgan.'**
  String get errorApprovalExpired;

  /// No description provided for @questionRejectRemoves.
  ///
  /// In uz, this message translates to:
  /// **'Rad etsangiz, bu mahsulot buyurtmadan olib tashlanadi.'**
  String get questionRejectRemoves;

  /// No description provided for @questionDropsReplacement.
  ///
  /// In uz, this message translates to:
  /// **'Rozi bo\'lsangiz, o\'rniga boshqasi emas, buyurtma qilingan mahsulotning o\'zi olinadi.'**
  String get questionDropsReplacement;

  /// No description provided for @decisionSending.
  ///
  /// In uz, this message translates to:
  /// **'Javob yuborilmoqda'**
  String get decisionSending;

  /// No description provided for @myDeliveries.
  ///
  /// In uz, this message translates to:
  /// **'Mening yetkazishlarim'**
  String get myDeliveries;

  /// No description provided for @courierChipNew.
  ///
  /// In uz, this message translates to:
  /// **'Yangi'**
  String get courierChipNew;

  /// No description provided for @courierChipAccepted.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilindi'**
  String get courierChipAccepted;

  /// No description provided for @courierAssigned.
  ///
  /// In uz, this message translates to:
  /// **'Tayinlandi: {when}'**
  String courierAssigned(String when);

  /// No description provided for @courierAccepted.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilindi: {when}'**
  String courierAccepted(String when);

  /// No description provided for @courierOnTheWayLine.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'lga chiqildi: {when} · {due} gacha'**
  String courierOnTheWayLine(String when, String due);

  /// No description provided for @courierOnTheWaySince.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'lga chiqildi: {when}'**
  String courierOnTheWaySince(String when);

  /// No description provided for @courierDeliveryWish.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazish: {wish}'**
  String courierDeliveryWish(String wish);

  /// No description provided for @courierRequestShort.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz bekor qilishni so\'ramoqda — yo\'lga chiqmang'**
  String get courierRequestShort;

  /// No description provided for @courierOpenToAccept.
  ///
  /// In uz, this message translates to:
  /// **'Oching va yetkazishni qabul qiling'**
  String get courierOpenToAccept;

  /// No description provided for @courierEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha yetkazish yo\'q'**
  String get courierEmptyTitle;

  /// No description provided for @courierOrdersEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Operator sizga yetkazish tayinlasa, u shu yerda paydo bo\'ladi. Ro\'yxat o\'zi yangilanadi.'**
  String get courierOrdersEmpty;

  /// No description provided for @courierPageEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Bu sahifada yetkazishlar qolmadi. Oldingi sahifaga o\'ting.'**
  String get courierPageEmpty;

  /// No description provided for @courierAccept.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazishni qabul qilish'**
  String get courierAccept;

  /// No description provided for @courierStart.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'lga chiqish'**
  String get courierStart;

  /// No description provided for @courierDelivered.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazildi'**
  String get courierDelivered;

  /// No description provided for @courierNotDelivered.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazilmadi'**
  String get courierNotDelivered;

  /// No description provided for @courierRequestPending.
  ///
  /// In uz, this message translates to:
  /// **'Operator hal qilmaguncha yo\'lga chiqmang'**
  String get courierRequestPending;

  /// No description provided for @courierPickupFromShopper.
  ///
  /// In uz, this message translates to:
  /// **'Topshirish joyi yo\'q — paketni bozorda yig\'uvchidan oling.'**
  String get courierPickupFromShopper;

  /// No description provided for @courierAddressTitle.
  ///
  /// In uz, this message translates to:
  /// **'Manzil'**
  String get courierAddressTitle;

  /// No description provided for @courierOpenYandex.
  ///
  /// In uz, this message translates to:
  /// **'Yandexda ochish'**
  String get courierOpenYandex;

  /// No description provided for @courierCopyAddress.
  ///
  /// In uz, this message translates to:
  /// **'Manzilni nusxalash'**
  String get courierCopyAddress;

  /// No description provided for @courierAddressCopied.
  ///
  /// In uz, this message translates to:
  /// **'Manzil nusxalandi'**
  String get courierAddressCopied;

  /// No description provided for @courierMapFailed.
  ///
  /// In uz, this message translates to:
  /// **'Yandex ochilmadi. Manzil: {address}'**
  String courierMapFailed(String address);

  /// No description provided for @courierCollect.
  ///
  /// In uz, this message translates to:
  /// **'Naqd olish kerak: {amount}'**
  String courierCollect(String amount);

  /// No description provided for @courierPaidOnline.
  ///
  /// In uz, this message translates to:
  /// **'Onlayn to\'langan — pul olinmaydi'**
  String get courierPaidOnline;

  /// No description provided for @courierStartedAt.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'lga chiqilgan: {time}'**
  String courierStartedAt(String time);

  /// No description provided for @courierDeliveredTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma qabul qiluvchiga topshirildimi?'**
  String get courierDeliveredTitle;

  /// No description provided for @courierCashPrompt.
  ///
  /// In uz, this message translates to:
  /// **'{amount} naqd oling va olingan summani kiriting.'**
  String courierCashPrompt(String amount);

  /// No description provided for @courierCashField.
  ///
  /// In uz, this message translates to:
  /// **'Naqd olindi, so\'m'**
  String get courierCashField;

  /// No description provided for @courierCashInvalid.
  ///
  /// In uz, this message translates to:
  /// **'Summani so\'mda, raqamlar bilan kiriting'**
  String get courierCashInvalid;

  /// No description provided for @courierCashMismatch.
  ///
  /// In uz, this message translates to:
  /// **'Summa mos emas: {amount} olinishi kerak.'**
  String courierCashMismatch(String amount);

  /// No description provided for @courierHandoverRepeating.
  ///
  /// In uz, this message translates to:
  /// **'Oldingi belgi javobsiz qoldi — xuddi shu summa qayta yuboriladi.'**
  String get courierHandoverRepeating;

  /// No description provided for @courierHandoverUnconfirmed.
  ///
  /// In uz, this message translates to:
  /// **'«Yetkazildi» belgisi yuborildi, lekin javob kelmadi. Qayta yuboring — ikkinchi to\'lov yozilmaydi.'**
  String get courierHandoverUnconfirmed;

  /// No description provided for @courierDeliveredDone.
  ///
  /// In uz, this message translates to:
  /// **'{number}-buyurtma yetkazildi'**
  String courierDeliveredDone(String number);

  /// No description provided for @courierNotDeliveredTitle.
  ///
  /// In uz, this message translates to:
  /// **'Nega yetkazib bo\'lmadi?'**
  String get courierNotDeliveredTitle;

  /// No description provided for @courierNotDeliveredNote.
  ///
  /// In uz, this message translates to:
  /// **'Izoh'**
  String get courierNotDeliveredNote;

  /// No description provided for @courierNotDeliveredNoteOptional.
  ///
  /// In uz, this message translates to:
  /// **'Izoh (ixtiyoriy)'**
  String get courierNotDeliveredNoteOptional;

  /// No description provided for @courierNotDeliveredNoteHint.
  ///
  /// In uz, this message translates to:
  /// **'Masalan: uch marta qo\'ng\'iroq qildim'**
  String get courierNotDeliveredNoteHint;

  /// No description provided for @courierOtherNoteHint.
  ///
  /// In uz, this message translates to:
  /// **'Nima bo\'lganini yozing'**
  String get courierOtherNoteHint;

  /// No description provided for @courierOnlineNothingToTake.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma onlayn to\'langan — pul olinmaydi.'**
  String get courierOnlineNothingToTake;

  /// No description provided for @courierNotDeliveredExplained.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma operatorga qaytadi, u keyin nima qilishni hal qiladi.'**
  String get courierNotDeliveredExplained;

  /// No description provided for @courierNotDeliveredDone.
  ///
  /// In uz, this message translates to:
  /// **'{number}-buyurtma operatorga qaytarildi'**
  String courierNotDeliveredDone(String number);

  /// No description provided for @courierOrderGone.
  ///
  /// In uz, this message translates to:
  /// **'Bu yetkazish endi sizda emas'**
  String get courierOrderGone;

  /// No description provided for @courierBack.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazishlarimga'**
  String get courierBack;

  /// No description provided for @courierStatusNew.
  ///
  /// In uz, this message translates to:
  /// **'Yangi yetkazish'**
  String get courierStatusNew;

  /// No description provided for @courierStatusNewHint.
  ///
  /// In uz, this message translates to:
  /// **'Manzilni ko\'rib chiqing va yetkazishni qabul qiling'**
  String get courierStatusNewHint;

  /// No description provided for @courierStatusAccepted.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazish qabul qilindi'**
  String get courierStatusAccepted;

  /// No description provided for @courierStatusAcceptedHint.
  ///
  /// In uz, this message translates to:
  /// **'№ {number} paketni oling va yo\'lga chiqing'**
  String courierStatusAcceptedHint(String number);

  /// No description provided for @courierStatusRequest.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz bekor qilishni so\'ramoqda'**
  String get courierStatusRequest;

  /// No description provided for @courierOnTheWayHint.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'lga chiqildi: {time} · {due} gacha yetkazing'**
  String courierOnTheWayHint(String time, String due);

  /// No description provided for @courierStepAssigned.
  ///
  /// In uz, this message translates to:
  /// **'Tayinlandi'**
  String get courierStepAssigned;

  /// No description provided for @courierStepAccepted.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilindi'**
  String get courierStepAccepted;

  /// No description provided for @courierStepOnTheWay.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'lda'**
  String get courierStepOnTheWay;

  /// No description provided for @courierStepDelivered.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazildi'**
  String get courierStepDelivered;

  /// No description provided for @courierNoWish.
  ///
  /// In uz, this message translates to:
  /// **'Vaqt bo\'yicha istak yo\'q'**
  String get courierNoWish;

  /// No description provided for @courierPickupAtPoint.
  ///
  /// In uz, this message translates to:
  /// **'№ {number} paket bozor yonidagi topshirish joyida kutmoqda.'**
  String courierPickupAtPoint(String number);

  /// No description provided for @courierCallShopper.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchiga qo\'ng\'iroq qilish'**
  String get courierCallShopper;

  /// No description provided for @courierRecipientTitle.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qiluvchi'**
  String get courierRecipientTitle;

  /// No description provided for @courierLandmarkLabel.
  ///
  /// In uz, this message translates to:
  /// **'Mo\'ljal'**
  String get courierLandmarkLabel;

  /// No description provided for @courierNoteLabel.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer uchun'**
  String get courierNoteLabel;

  /// No description provided for @courierPaymentTitle.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov'**
  String get courierPaymentTitle;

  /// No description provided for @courierCollectLabel.
  ///
  /// In uz, this message translates to:
  /// **'Naqd pul olish'**
  String get courierCollectLabel;

  /// No description provided for @courierPaidOnlineLabel.
  ///
  /// In uz, this message translates to:
  /// **'Onlayn to\'langan'**
  String get courierPaidOnlineLabel;

  /// No description provided for @courierNoCash.
  ///
  /// In uz, this message translates to:
  /// **'Pul olinmaydi'**
  String get courierNoCash;

  /// No description provided for @courierWaitOperator.
  ///
  /// In uz, this message translates to:
  /// **'Operator qarorini kutyapmiz'**
  String get courierWaitOperator;

  /// No description provided for @courierDeliveredAgain.
  ///
  /// In uz, this message translates to:
  /// **'«Yetkazildi»ni qayta yuborish'**
  String get courierDeliveredAgain;

  /// No description provided for @courierOrderGoneHint.
  ///
  /// In uz, this message translates to:
  /// **'U yopilgan, bekor qilingan yoki boshqa kuryerga berilgan.'**
  String get courierOrderGoneHint;

  /// No description provided for @errorDeliveryStateConflict.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazish allaqachon o\'zgargan, buyurtma yangilandi.'**
  String get errorDeliveryStateConflict;

  /// No description provided for @errorCashAmountMismatch.
  ///
  /// In uz, this message translates to:
  /// **'Summa olinishi kerak bo\'lgan summaga mos emas.'**
  String get errorCashAmountMismatch;

  /// No description provided for @getCodeButton.
  ///
  /// In uz, this message translates to:
  /// **'Kod olish'**
  String get getCodeButton;

  /// No description provided for @codeComesInTelegram.
  ///
  /// In uz, this message translates to:
  /// **'Kod Telegramga keladi'**
  String get codeComesInTelegram;

  /// No description provided for @legalEdition.
  ///
  /// In uz, this message translates to:
  /// **'Tahrir: {date}'**
  String legalEdition(String date);

  /// No description provided for @legalNotPublishedYet.
  ///
  /// In uz, this message translates to:
  /// **'Hujjat hali e\'lon qilinmagan.'**
  String get legalNotPublishedYet;

  /// No description provided for @consentAll.
  ///
  /// In uz, this message translates to:
  /// **'Davom etib, siz {terms} va {privacy}ni qabul qilasiz'**
  String consentAll(String terms, String privacy);

  /// No description provided for @consentTermsOnly.
  ///
  /// In uz, this message translates to:
  /// **'Davom etib, siz {terms}ni qabul qilasiz'**
  String consentTermsOnly(String terms);

  /// No description provided for @consentPrivacyOnly.
  ///
  /// In uz, this message translates to:
  /// **'Davom etib, siz {privacy}ni qabul qilasiz'**
  String consentPrivacyOnly(String privacy);

  /// No description provided for @consentTermsLink.
  ///
  /// In uz, this message translates to:
  /// **'Foydalanish shartlari'**
  String get consentTermsLink;

  /// No description provided for @consentPrivacyLink.
  ///
  /// In uz, this message translates to:
  /// **'Maxfiylik siyosati'**
  String get consentPrivacyLink;

  /// No description provided for @confirmPhoneTitle.
  ///
  /// In uz, this message translates to:
  /// **'Raqamni tekshiring'**
  String get confirmPhoneTitle;

  /// No description provided for @confirmPhoneBody.
  ///
  /// In uz, this message translates to:
  /// **'Unga Telegramda kod yuboramiz'**
  String get confirmPhoneBody;

  /// No description provided for @editButton.
  ///
  /// In uz, this message translates to:
  /// **'O\'zgartirish'**
  String get editButton;

  /// No description provided for @sendButton.
  ///
  /// In uz, this message translates to:
  /// **'Yuborish'**
  String get sendButton;

  /// No description provided for @codeTitle.
  ///
  /// In uz, this message translates to:
  /// **'Kodni kiriting'**
  String get codeTitle;

  /// No description provided for @nameTitle.
  ///
  /// In uz, this message translates to:
  /// **'Ismingiz nima?'**
  String get nameTitle;

  /// No description provided for @nameSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Ism yig\'uvchi va kuryerga kerak'**
  String get nameSubtitle;

  /// No description provided for @welcomeTitle.
  ///
  /// In uz, this message translates to:
  /// **'Xush kelibsiz, {name}!'**
  String welcomeTitle(String name);

  /// No description provided for @welcomeBody.
  ///
  /// In uz, this message translates to:
  /// **'Bozordan yangi mahsulotlar sizni kutmoqda'**
  String get welcomeBody;

  /// No description provided for @welcomeButton.
  ///
  /// In uz, this message translates to:
  /// **'Xaridlarga'**
  String get welcomeButton;

  /// No description provided for @staffPasswordTitle.
  ///
  /// In uz, this message translates to:
  /// **'Xodim sifatida kirish'**
  String get staffPasswordTitle;

  /// No description provided for @staffPasswordSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Raqam tasdiqlandi. Xodim parolini kiriting'**
  String get staffPasswordSubtitle;

  /// No description provided for @panelTagline.
  ///
  /// In uz, this message translates to:
  /// **'Boshqaruv paneli'**
  String get panelTagline;

  /// No description provided for @staffPasswordForgot.
  ///
  /// In uz, this message translates to:
  /// **'Parolni unutdingizmi? Administratorga murojaat qiling'**
  String get staffPasswordForgot;

  /// No description provided for @staffPasswordWrong.
  ///
  /// In uz, this message translates to:
  /// **'Noto\'g\'ri parol'**
  String get staffPasswordWrong;

  /// No description provided for @staffStepExpired.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlash muddati tugadi. Yangi kod oling'**
  String get staffStepExpired;

  /// No description provided for @getNewCodeButton.
  ///
  /// In uz, this message translates to:
  /// **'Yangi kod olish'**
  String get getNewCodeButton;

  /// No description provided for @showPassword.
  ///
  /// In uz, this message translates to:
  /// **'Parolni ko\'rsatish'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In uz, this message translates to:
  /// **'Parolni yashirish'**
  String get hidePassword;

  /// No description provided for @back.
  ///
  /// In uz, this message translates to:
  /// **'Orqaga'**
  String get back;

  /// No description provided for @wrongSurfaceWebTitle.
  ///
  /// In uz, this message translates to:
  /// **'Ilovani oching'**
  String get wrongSurfaceWebTitle;

  /// No description provided for @catalogApproxPrice.
  ///
  /// In uz, this message translates to:
  /// **'≈ {price}'**
  String catalogApproxPrice(String price);

  /// No description provided for @catalogPerUnit.
  ///
  /// In uz, this message translates to:
  /// **'{unit} uchun'**
  String catalogPerUnit(String unit);

  /// No description provided for @catalogAdd.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'shish'**
  String get catalogAdd;

  /// No description provided for @catalogUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Sotuvda yo\'q'**
  String get catalogUnavailable;

  /// No description provided for @favoriteFailed.
  ///
  /// In uz, this message translates to:
  /// **'Saqlab bo\'lmadi. Qayta urinib ko\'ring'**
  String get favoriteFailed;

  /// No description provided for @favoritesFull.
  ///
  /// In uz, this message translates to:
  /// **'Sevimlilar to\'ldi: 500 tadan ko\'p bo\'lmaydi'**
  String get favoritesFull;

  /// No description provided for @favoriteAdd.
  ///
  /// In uz, this message translates to:
  /// **'Sevimlilarga qo\'shish'**
  String get favoriteAdd;

  /// No description provided for @favoriteRemove.
  ///
  /// In uz, this message translates to:
  /// **'Sevimlilardan olib tashlash'**
  String get favoriteRemove;

  /// No description provided for @cartStepMinus.
  ///
  /// In uz, this message translates to:
  /// **'Kamaytirish'**
  String get cartStepMinus;

  /// No description provided for @cartStepPlus.
  ///
  /// In uz, this message translates to:
  /// **'Ko\'paytirish'**
  String get cartStepPlus;

  /// No description provided for @sortTitle.
  ///
  /// In uz, this message translates to:
  /// **'Saralash'**
  String get sortTitle;

  /// No description provided for @sortShop.
  ///
  /// In uz, this message translates to:
  /// **'Do\'kondagidek'**
  String get sortShop;

  /// No description provided for @sortPriceAsc.
  ///
  /// In uz, this message translates to:
  /// **'Avval arzonlari'**
  String get sortPriceAsc;

  /// No description provided for @sortPriceDesc.
  ///
  /// In uz, this message translates to:
  /// **'Avval qimmatlari'**
  String get sortPriceDesc;

  /// No description provided for @allProductsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Barcha mahsulotlar'**
  String get allProductsTitle;

  /// No description provided for @recommendedTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tavsiya etamiz'**
  String get recommendedTitle;

  /// No description provided for @recommendedEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha tavsiya etilgan mahsulot yo\'q'**
  String get recommendedEmpty;

  /// No description provided for @cartSummaryCount.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, other{{count} ta mahsulot}}'**
  String cartSummaryCount(int count);

  /// No description provided for @cartSummaryOpen.
  ///
  /// In uz, this message translates to:
  /// **'Savatga'**
  String get cartSummaryOpen;

  /// No description provided for @favoritesTitle.
  ///
  /// In uz, this message translates to:
  /// **'Sevimlilar'**
  String get favoritesTitle;

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha bo\'sh'**
  String get favoritesEmptyTitle;

  /// No description provided for @favoritesEmptyText.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotdagi yurakchani bosing — u shu yerda paydo bo\'ladi va uni qayta buyurtma qilish oson bo\'ladi'**
  String get favoritesEmptyText;

  /// No description provided for @favoritesEmptyAction.
  ///
  /// In uz, this message translates to:
  /// **'Xaridga'**
  String get favoritesEmptyAction;

  /// No description provided for @searchRecentTitle.
  ///
  /// In uz, this message translates to:
  /// **'So\'nggi so\'rovlar'**
  String get searchRecentTitle;

  /// No description provided for @searchRecentClear.
  ///
  /// In uz, this message translates to:
  /// **'Tozalash'**
  String get searchRecentClear;

  /// No description provided for @searchFound.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, other{Topildi: {count} ta mahsulot}}'**
  String searchFound(int count);

  /// No description provided for @searchNothingTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hech narsa topilmadi'**
  String get searchNothingTitle;

  /// No description provided for @searchNothingText.
  ///
  /// In uz, this message translates to:
  /// **'«{query}» bo\'yicha mahsulot yo\'q. Yozilishini tekshiring — biz o\'zbekcha ham, ruscha ham qidiramiz.'**
  String searchNothingText(String query);

  /// No description provided for @searchAllCategories.
  ///
  /// In uz, this message translates to:
  /// **'Barcha kategoriyalar'**
  String get searchAllCategories;

  /// No description provided for @openSearch.
  ///
  /// In uz, this message translates to:
  /// **'Qidirish'**
  String get openSearch;

  /// No description provided for @productTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot haqida'**
  String get productTitle;

  /// No description provided for @productReadMore.
  ///
  /// In uz, this message translates to:
  /// **'Batafsil'**
  String get productReadMore;

  /// No description provided for @productReadLess.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'ish'**
  String get productReadLess;

  /// No description provided for @productIfMissing.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot bo\'lmasa'**
  String get productIfMissing;

  /// No description provided for @productNoteHint.
  ///
  /// In uz, this message translates to:
  /// **'Masalan: qattiqroq, pishib o\'tmagan'**
  String get productNoteHint;

  /// No description provided for @productMoreIn.
  ///
  /// In uz, this message translates to:
  /// **'«{category}» bo\'limidan yana'**
  String productMoreIn(String category);

  /// No description provided for @productMoreGeneric.
  ///
  /// In uz, this message translates to:
  /// **'Shu bo\'limdan yana'**
  String get productMoreGeneric;

  /// No description provided for @productAddToCart.
  ///
  /// In uz, this message translates to:
  /// **'Savatga'**
  String get productAddToCart;

  /// No description provided for @productGoneTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bu mahsulot endi sotilmaydi'**
  String get productGoneTitle;

  /// No description provided for @productGoneText.
  ///
  /// In uz, this message translates to:
  /// **'U katalogdan olib tashlangan. O\'xshash mahsulotlarni bo\'limlarda topish mumkin.'**
  String get productGoneText;

  /// No description provided for @productGoneAction.
  ///
  /// In uz, this message translates to:
  /// **'Katalogga'**
  String get productGoneAction;

  /// No description provided for @productInCart.
  ///
  /// In uz, this message translates to:
  /// **'Savatda: {quantity}'**
  String productInCart(String quantity);

  /// No description provided for @productSave.
  ///
  /// In uz, this message translates to:
  /// **'Saqlash'**
  String get productSave;

  /// No description provided for @cartLineSaved.
  ///
  /// In uz, this message translates to:
  /// **'Savat yangilandi'**
  String get cartLineSaved;

  /// No description provided for @productAlreadyInCart.
  ///
  /// In uz, this message translates to:
  /// **'Bu mahsulot savatda bor — o\'zgartirib, saqlashingiz mumkin'**
  String get productAlreadyInCart;

  /// No description provided for @quantitySheetTitle.
  ///
  /// In uz, this message translates to:
  /// **'Miqdor'**
  String get quantitySheetTitle;

  /// No description provided for @quantitySheetDone.
  ///
  /// In uz, this message translates to:
  /// **'Tayyor'**
  String get quantitySheetDone;

  /// No description provided for @cartUnitPrice.
  ///
  /// In uz, this message translates to:
  /// **'{unit} uchun ≈ {price}'**
  String cartUnitPrice(String unit, String price);

  /// No description provided for @cartUnitPriceExact.
  ///
  /// In uz, this message translates to:
  /// **'{unit} uchun {price}'**
  String cartUnitPriceExact(String unit, String price);

  /// No description provided for @cartRemoveTitle.
  ///
  /// In uz, this message translates to:
  /// **'Savatdan olib tashlansinmi?'**
  String get cartRemoveTitle;

  /// No description provided for @cartRemoveConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Olib tashlash'**
  String get cartRemoveConfirm;

  /// No description provided for @cartEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Savat hozircha bo\'sh'**
  String get cartEmptyTitle;

  /// No description provided for @cartEmptyText.
  ///
  /// In uz, this message translates to:
  /// **'Katalogdan mahsulot qo\'shing — yig\'uvchi ularni bozordan oladi, kuryer olib keladi.'**
  String get cartEmptyText;

  /// No description provided for @cartGoods.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlar ({count})'**
  String cartGoods(int count);

  /// No description provided for @cartDelivery.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazib berish'**
  String get cartDelivery;

  /// No description provided for @cartServiceFee.
  ///
  /// In uz, this message translates to:
  /// **'Xizmat haqi'**
  String get cartServiceFee;

  /// No description provided for @cartTotal.
  ///
  /// In uz, this message translates to:
  /// **'Jami'**
  String get cartTotal;

  /// No description provided for @cartEstimateNote.
  ///
  /// In uz, this message translates to:
  /// **'Summa taxminiy. Yakuniy summani xariddan keyin bozor narxlari bo\'yicha hisoblaymiz; narx ruxsat etilganidan oshsa — sizdan so\'raymiz.'**
  String get cartEstimateNote;

  /// No description provided for @cartMinimumShort.
  ///
  /// In uz, this message translates to:
  /// **'Minimal buyurtmagacha {amount} yetmayapti'**
  String cartMinimumShort(String amount);

  /// No description provided for @cartMinimumRule.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlarning minimal summasi — {amount}, yetkazib berish va xizmat haqisiz'**
  String cartMinimumRule(String amount);

  /// No description provided for @cartWhyUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Avval sotuvda yo\'q mahsulotlarni olib tashlang'**
  String get cartWhyUnavailable;

  /// No description provided for @cartWhyMinimum.
  ///
  /// In uz, this message translates to:
  /// **'Minimal buyurtma — {amount}'**
  String cartWhyMinimum(String amount);

  /// No description provided for @cartAddMoreTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmaga qo\'shing'**
  String get cartAddMoreTitle;

  /// No description provided for @cartDeliveryTo.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazish:'**
  String get cartDeliveryTo;

  /// No description provided for @settingsSupportPhone.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'llab-quvvatlash telefoni'**
  String get settingsSupportPhone;

  /// No description provided for @settingsSupportPhoneHint.
  ///
  /// In uz, this message translates to:
  /// **'+998 va 9 raqam; bo\'sh bo\'lsa tugma ko\'rinmaydi'**
  String get settingsSupportPhoneHint;

  /// No description provided for @fieldSupportPhone.
  ///
  /// In uz, this message translates to:
  /// **'Raqamni kiriting: +998 va 9 raqam'**
  String get fieldSupportPhone;

  /// No description provided for @attentionLowRating.
  ///
  /// In uz, this message translates to:
  /// **'Past baho'**
  String get attentionLowRating;

  /// No description provided for @ratingTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz bahosi'**
  String get ratingTitle;

  /// No description provided for @ratingStars.
  ///
  /// In uz, this message translates to:
  /// **'Baho: 5 dan {count}'**
  String ratingStars(int count);

  /// No description provided for @ratingReasonNotFresh.
  ///
  /// In uz, this message translates to:
  /// **'Yangi emas'**
  String get ratingReasonNotFresh;

  /// No description provided for @ratingReasonWrongWeight.
  ///
  /// In uz, this message translates to:
  /// **'Og\'irligi noto\'g\'ri'**
  String get ratingReasonWrongWeight;

  /// No description provided for @ratingReasonLate.
  ///
  /// In uz, this message translates to:
  /// **'Kechikdi'**
  String get ratingReasonLate;

  /// No description provided for @ratingReasonRude.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'pol'**
  String get ratingReasonRude;

  /// No description provided for @ratingReview.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz bilan bog\'lanildi'**
  String get ratingReview;

  /// No description provided for @ratingReviewed.
  ///
  /// In uz, this message translates to:
  /// **'Ko\'rib chiqildi: {name}, {time}'**
  String ratingReviewed(String name, String time);

  /// No description provided for @dayToday.
  ///
  /// In uz, this message translates to:
  /// **'Bugun'**
  String get dayToday;

  /// No description provided for @dayYesterday.
  ///
  /// In uz, this message translates to:
  /// **'Kecha'**
  String get dayYesterday;

  /// No description provided for @dayDate.
  ///
  /// In uz, this message translates to:
  /// **'{day}-{month}'**
  String dayDate(String day, String month);

  /// No description provided for @monthShort.
  ///
  /// In uz, this message translates to:
  /// **'{month, select, m1{yan} m2{fev} m3{mar} m4{apr} m5{may} m6{iyn} m7{iyl} m8{avg} m9{sen} m10{okt} m11{noy} m12{dek} other{}}'**
  String monthShort(String month);

  /// No description provided for @orderWhen.
  ///
  /// In uz, this message translates to:
  /// **'{day}, {time}'**
  String orderWhen(String day, String time);

  /// No description provided for @orderAt.
  ///
  /// In uz, this message translates to:
  /// **'{day}, soat {time}'**
  String orderAt(String day, String time);

  /// No description provided for @reorderTitle.
  ///
  /// In uz, this message translates to:
  /// **'Savatga qo\'shildi'**
  String get reorderTitle;

  /// No description provided for @reorderNothingTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hech narsa qo\'shilmadi'**
  String get reorderNothingTitle;

  /// No description provided for @reorderAdded.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, other{Buyurtma № {number} dan {count} ta mahsulot — bugungi narxlarda.}}'**
  String reorderAdded(int count, int number);

  /// No description provided for @reorderSkippedTitle.
  ///
  /// In uz, this message translates to:
  /// **'Savatda bor edi — o\'zgartirmadik'**
  String get reorderSkippedTitle;

  /// No description provided for @reorderInCart.
  ///
  /// In uz, this message translates to:
  /// **'Savatda {quantity}'**
  String reorderInCart(String quantity);

  /// No description provided for @reorderUnavailableTitle.
  ///
  /// In uz, this message translates to:
  /// **'Sotuvda yo\'q — qo\'shilmadi'**
  String get reorderUnavailableTitle;

  /// No description provided for @reorderCartFullTitle.
  ///
  /// In uz, this message translates to:
  /// **'Sig\'madi — savatda 100 ta mahsulot bor'**
  String get reorderCartFullTitle;

  /// No description provided for @reorderStay.
  ///
  /// In uz, this message translates to:
  /// **'Qolish'**
  String get reorderStay;

  /// No description provided for @reorderToCart.
  ///
  /// In uz, this message translates to:
  /// **'Savatga'**
  String get reorderToCart;

  /// No description provided for @reorderRepeat.
  ///
  /// In uz, this message translates to:
  /// **'Takrorlash'**
  String get reorderRepeat;

  /// No description provided for @reorderRepeatOrder.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmani takrorlash'**
  String get reorderRepeatOrder;

  /// No description provided for @reorderSending.
  ///
  /// In uz, this message translates to:
  /// **'Savatga qo\'shilmoqda'**
  String get reorderSending;

  /// No description provided for @questionBannerTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi javobingizni kutmoqda'**
  String get questionBannerTitle;

  /// No description provided for @questionBannerOrder.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma № {number} · {time} gacha javob bering'**
  String questionBannerOrder(String number, String time);

  /// No description provided for @questionAnswer.
  ///
  /// In uz, this message translates to:
  /// **'Javob berish'**
  String get questionAnswer;

  /// No description provided for @ordersTabCurrent.
  ///
  /// In uz, this message translates to:
  /// **'Joriy'**
  String get ordersTabCurrent;

  /// No description provided for @ordersTabPast.
  ///
  /// In uz, this message translates to:
  /// **'O\'tgan'**
  String get ordersTabPast;

  /// No description provided for @customerOrderTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma № {number}'**
  String customerOrderTitle(int number);

  /// No description provided for @orderItemCount.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, other{{count} ta mahsulot}}'**
  String orderItemCount(int count);

  /// No description provided for @orderCardQuestion.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, other{Yig\'uvchi {count} ta mahsulot haqida so\'ramoqda}}'**
  String orderCardQuestion(int count);

  /// No description provided for @callCourier.
  ///
  /// In uz, this message translates to:
  /// **'Kuryerga qo\'ng\'iroq qilish'**
  String get callCourier;

  /// No description provided for @ordersEmptyHint.
  ///
  /// In uz, this message translates to:
  /// **'Savatni to\'ldiring — yig\'uvchi hammasini bozordan oladi, kuryer esa olib keladi.'**
  String get ordersEmptyHint;

  /// No description provided for @ordersEmptyAction.
  ///
  /// In uz, this message translates to:
  /// **'Xaridga'**
  String get ordersEmptyAction;

  /// No description provided for @ordersPastEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Bu yerda yetkazilgan va bekor qilingan buyurtmalar bo\'ladi'**
  String get ordersPastEmpty;

  /// No description provided for @rateStarsLabel.
  ///
  /// In uz, this message translates to:
  /// **'5 dan {stars} ga baholash'**
  String rateStarsLabel(int stars);

  /// No description provided for @ratedStarsLabel.
  ///
  /// In uz, this message translates to:
  /// **'Baho: 5 dan {stars}'**
  String ratedStarsLabel(int stars);

  /// No description provided for @orderStateAccepted.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma qabul qilindi'**
  String get orderStateAccepted;

  /// No description provided for @orderStateAcceptedHint.
  ///
  /// In uz, this message translates to:
  /// **'Tez orada yig\'uvchi bozordan xarid qilishni boshlaydi'**
  String get orderStateAcceptedHint;

  /// No description provided for @orderStateShopping.
  ///
  /// In uz, this message translates to:
  /// **'Bozordan xarid qilyapmiz'**
  String get orderStateShopping;

  /// No description provided for @orderStateShoppingHint.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi mahsulotlaringizni tanlayapti'**
  String get orderStateShoppingHint;

  /// No description provided for @orderStateCollected.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma yig\'ildi'**
  String get orderStateCollected;

  /// No description provided for @orderStateCollectedHint.
  ///
  /// In uz, this message translates to:
  /// **'Tez orada kuryer olib ketadi'**
  String get orderStateCollectedHint;

  /// No description provided for @orderStateOnTheWay.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer buyurtmani olib kelmoqda'**
  String get orderStateOnTheWay;

  /// No description provided for @orderStateLeftAt.
  ///
  /// In uz, this message translates to:
  /// **'Soat {time} da yo\'lga chiqdi'**
  String orderStateLeftAt(String time);

  /// No description provided for @orderStateDelivered.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazildi'**
  String get orderStateDelivered;

  /// No description provided for @orderStateCancelled.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma bekor qilindi'**
  String get orderStateCancelled;

  /// No description provided for @orderCancelledByYou.
  ///
  /// In uz, this message translates to:
  /// **'Siz bekor qildingiz: {when}'**
  String orderCancelledByYou(String when);

  /// No description provided for @orderCancelledWhen.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilindi: {when}'**
  String orderCancelledWhen(String when);

  /// No description provided for @orderCancelReasonQuoted.
  ///
  /// In uz, this message translates to:
  /// **'Sabab: «{reason}»'**
  String orderCancelReasonQuoted(String reason);

  /// No description provided for @progressAccepted.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilindi'**
  String get progressAccepted;

  /// No description provided for @progressShopping.
  ///
  /// In uz, this message translates to:
  /// **'Xarid'**
  String get progressShopping;

  /// No description provided for @progressDelivering.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'lda'**
  String get progressDelivering;

  /// No description provided for @progressDelivered.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazildi'**
  String get progressDelivered;

  /// No description provided for @orderCanStillChange.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi boshlamaguncha buyurtmani o\'zgartirish yoki bekor qilish mumkin.'**
  String get orderCanStillChange;

  /// No description provided for @orderLineBoughtKit.
  ///
  /// In uz, this message translates to:
  /// **'Sotib olindi: {quantity} × {price}'**
  String orderLineBoughtKit(String quantity, String price);

  /// No description provided for @lineTagBought.
  ///
  /// In uz, this message translates to:
  /// **'Sotib olindi'**
  String get lineTagBought;

  /// No description provided for @lineTagWaiting.
  ///
  /// In uz, this message translates to:
  /// **'Javobingizni kutmoqda'**
  String get lineTagWaiting;

  /// No description provided for @lineTagUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Bozorda yo\'q edi — olib tashlandi'**
  String get lineTagUnavailable;

  /// No description provided for @lineTagRejected.
  ///
  /// In uz, this message translates to:
  /// **'Siz rad etdingiz — olib tashlandi'**
  String get lineTagRejected;

  /// No description provided for @lineTagExpired.
  ///
  /// In uz, this message translates to:
  /// **'Vaqtida javob berilmadi — olib tashlandi'**
  String get lineTagExpired;

  /// No description provided for @lineTagOperator.
  ///
  /// In uz, this message translates to:
  /// **'Operator olib tashladi'**
  String get lineTagOperator;

  /// No description provided for @orderToPayLabel.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov'**
  String get orderToPayLabel;

  /// No description provided for @orderNothingDue.
  ///
  /// In uz, this message translates to:
  /// **'yo\'q'**
  String get orderNothingDue;

  /// No description provided for @orderPaidCash.
  ///
  /// In uz, this message translates to:
  /// **'Naqd to\'landi'**
  String get orderPaidCash;

  /// No description provided for @orderPaidOnline.
  ///
  /// In uz, this message translates to:
  /// **'Onlayn to\'landi'**
  String get orderPaidOnline;

  /// No description provided for @orderPaidWhen.
  ///
  /// In uz, this message translates to:
  /// **'{amount}, {when}'**
  String orderPaidWhen(String amount, String when);

  /// No description provided for @orderToPayAmount.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov: {amount}'**
  String orderToPayAmount(String amount);

  /// No description provided for @orderCashOnDelivery.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilganda kuryerga naqd'**
  String get orderCashOnDelivery;

  /// No description provided for @orderAddressTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazish manzili'**
  String get orderAddressTitle;

  /// No description provided for @supportTitle.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'llab-quvvatlash'**
  String get supportTitle;

  /// No description provided for @supportHint.
  ///
  /// In uz, this message translates to:
  /// **'Agar biror narsa noto\'g\'ri ketsa'**
  String get supportHint;

  /// No description provided for @callAction.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'ng\'iroq'**
  String get callAction;

  /// No description provided for @courierYours.
  ///
  /// In uz, this message translates to:
  /// **'Sizning kuryeringiz'**
  String get courierYours;

  /// No description provided for @orderCancelShort.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish'**
  String get orderCancelShort;

  /// No description provided for @requestYouAsked.
  ///
  /// In uz, this message translates to:
  /// **'Siz bekor qilishni so\'radingiz'**
  String get requestYouAsked;

  /// No description provided for @requestPendingHint.
  ///
  /// In uz, this message translates to:
  /// **'Operator hal qiladi — sizga xabar beramiz. Hozircha buyurtma ishda.'**
  String get requestPendingHint;

  /// No description provided for @cancelSheetTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma № {number} bekor qilinsinmi?'**
  String cancelSheetTitle(int number);

  /// No description provided for @cancelSheetHint.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi hali xarid qilishni boshlamadi — darhol bekor qilamiz.'**
  String get cancelSheetHint;

  /// No description provided for @requestSheetTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilishni so\'raysizmi?'**
  String get requestSheetTitle;

  /// No description provided for @requestSheetHint.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchi allaqachon xarid qilmoqda. Sababini yozing — operator hal qilib, sizga xabar beradi.'**
  String get requestSheetHint;

  /// No description provided for @cancelReasonHint.
  ///
  /// In uz, this message translates to:
  /// **'Masalan: noto\'g\'ri buyurtma berdim'**
  String get cancelReasonHint;

  /// No description provided for @orderCancelKeepKit.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilmaslik'**
  String get orderCancelKeepKit;

  /// No description provided for @requestSend.
  ///
  /// In uz, this message translates to:
  /// **'Yuborish'**
  String get requestSend;

  /// No description provided for @rateTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmani baholash'**
  String get rateTitle;

  /// No description provided for @rateQuestion.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma № {number} sizga yoqdimi?'**
  String rateQuestion(int number);

  /// No description provided for @rateHint.
  ///
  /// In uz, this message translates to:
  /// **'Hammasini baholang: mahsulotlar yangiligi, og\'irligi va yetkazib berish'**
  String get rateHint;

  /// No description provided for @rateStar1.
  ///
  /// In uz, this message translates to:
  /// **'Juda yomon'**
  String get rateStar1;

  /// No description provided for @rateStar2.
  ///
  /// In uz, this message translates to:
  /// **'Yomon'**
  String get rateStar2;

  /// No description provided for @rateStar3.
  ///
  /// In uz, this message translates to:
  /// **'O\'rtacha'**
  String get rateStar3;

  /// No description provided for @rateStar4.
  ///
  /// In uz, this message translates to:
  /// **'Yaxshi'**
  String get rateStar4;

  /// No description provided for @rateStar5.
  ///
  /// In uz, this message translates to:
  /// **'A\'lo!'**
  String get rateStar5;

  /// No description provided for @rateWhatWrong.
  ///
  /// In uz, this message translates to:
  /// **'Nima noto\'g\'ri bo\'ldi?'**
  String get rateWhatWrong;

  /// No description provided for @rateComment.
  ///
  /// In uz, this message translates to:
  /// **'Izoh (ixtiyoriy)'**
  String get rateComment;

  /// No description provided for @rateCommentHintGood.
  ///
  /// In uz, this message translates to:
  /// **'Nima yoqdi?'**
  String get rateCommentHintGood;

  /// No description provided for @rateCommentHintBad.
  ///
  /// In uz, this message translates to:
  /// **'Nima bo\'ldi?'**
  String get rateCommentHintBad;

  /// No description provided for @rateOperatorWillCall.
  ///
  /// In uz, this message translates to:
  /// **'Operator bahoni ko\'radi va vaziyatni aniqlash uchun siz bilan bog\'lanadi.'**
  String get rateOperatorWillCall;

  /// No description provided for @rateSend.
  ///
  /// In uz, this message translates to:
  /// **'Yuborish'**
  String get rateSend;

  /// No description provided for @rateSending.
  ///
  /// In uz, this message translates to:
  /// **'Baho yuborilmoqda'**
  String get rateSending;

  /// No description provided for @rateBlockTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma yoqdimi?'**
  String get rateBlockTitle;

  /// No description provided for @rateBlockHint.
  ///
  /// In uz, this message translates to:
  /// **'Yangilik, og\'irlik, yetkazish — 7 kun ichida baholash mumkin'**
  String get rateBlockHint;

  /// No description provided for @ratedTitle.
  ///
  /// In uz, this message translates to:
  /// **'Sizning bahoingiz'**
  String get ratedTitle;

  /// No description provided for @ratedThanksLow.
  ///
  /// In uz, this message translates to:
  /// **'Rahmat! Operator vaziyatni aniqlash uchun siz bilan bog\'lanadi.'**
  String get ratedThanksLow;

  /// No description provided for @ratedThanks.
  ///
  /// In uz, this message translates to:
  /// **'Baho uchun rahmat!'**
  String get ratedThanks;

  /// No description provided for @rateWindowClosed.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmani yetkazilgandan keyin 7 kun ichida baholash mumkin — bu vaqt o\'tdi.'**
  String get rateWindowClosed;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In uz, this message translates to:
  /// **'Akkauntni o\'chirasizmi?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteErasedHeading.
  ///
  /// In uz, this message translates to:
  /// **'O\'chiriladi'**
  String get deleteErasedHeading;

  /// No description provided for @deleteErasedName.
  ///
  /// In uz, this message translates to:
  /// **'Ism va telefon raqami'**
  String get deleteErasedName;

  /// No description provided for @deleteErasedAddresses.
  ///
  /// In uz, this message translates to:
  /// **'Manzillar'**
  String get deleteErasedAddresses;

  /// No description provided for @deleteErasedFavorites.
  ///
  /// In uz, this message translates to:
  /// **'Sevimlilar va savat'**
  String get deleteErasedFavorites;

  /// No description provided for @deleteKeptHeading.
  ///
  /// In uz, this message translates to:
  /// **'Qoladi'**
  String get deleteKeptHeading;

  /// No description provided for @deleteKeptOrders.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalar tarixi — ism va telefonsiz, hisob uchun'**
  String get deleteKeptOrders;

  /// No description provided for @deleteNote.
  ///
  /// In uz, this message translates to:
  /// **'Akkauntni qaytarib bo\'lmaydi. Bu raqam bilan yana kirish mumkin — yangi xaridor sifatida.'**
  String get deleteNote;

  /// No description provided for @deleteConfirm.
  ///
  /// In uz, this message translates to:
  /// **'O\'chirish'**
  String get deleteConfirm;

  /// No description provided for @deleteBlockedTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hozir o\'chirib bo\'lmaydi'**
  String get deleteBlockedTitle;

  /// No description provided for @deleteBlockedBody.
  ///
  /// In uz, this message translates to:
  /// **'№ {number} buyurtma hali tugallanmagan. Akkauntni buyurtma yetkazilgan yoki bekor qilingandan keyin o\'chirish mumkin.'**
  String deleteBlockedBody(int number);

  /// No description provided for @understoodButton.
  ///
  /// In uz, this message translates to:
  /// **'Tushunarli'**
  String get understoodButton;

  /// No description provided for @toOrderButton.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmaga'**
  String get toOrderButton;

  /// No description provided for @deleteCodeTitle.
  ///
  /// In uz, this message translates to:
  /// **'Akkauntni o\'chirish'**
  String get deleteCodeTitle;

  /// No description provided for @deleteCodeHeading.
  ///
  /// In uz, this message translates to:
  /// **'O\'chirishni tasdiqlang'**
  String get deleteCodeHeading;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In uz, this message translates to:
  /// **'Akkauntni o\'chirish'**
  String get profileDeleteAccount;

  /// No description provided for @deletedTitle.
  ///
  /// In uz, this message translates to:
  /// **'Akkaunt o\'chirildi'**
  String get deletedTitle;

  /// No description provided for @deletedBody.
  ///
  /// In uz, this message translates to:
  /// **'Ma\'lumotlaringiz o\'chirildi.\nBiz bilan bo\'lganingiz uchun rahmat.'**
  String get deletedBody;

  /// No description provided for @shopperMarketPer.
  ///
  /// In uz, this message translates to:
  /// **'Bozor narxi: {price} / {unit}'**
  String shopperMarketPer(String price, String unit);

  /// No description provided for @shopperBoundPer.
  ///
  /// In uz, this message translates to:
  /// **'Mijozdan so\'ramasdan — {unit} uchun {price} gacha'**
  String shopperBoundPer(String price, String unit);

  /// No description provided for @shopperCapAgreed.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz {ordered} o\'rniga {quantity} ga rozi'**
  String shopperCapAgreed(String quantity, String ordered);

  /// No description provided for @shopperCapBuy.
  ///
  /// In uz, this message translates to:
  /// **'{quantity} dan ko\'p olmang'**
  String shopperCapBuy(String quantity);

  /// No description provided for @shopperReplacementApproved.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz almashtirishga rozi bo\'ldi'**
  String get shopperReplacementApproved;

  /// No description provided for @shopperReplacementAutomatic.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz o\'xshashiga almashtirishga ruxsat bergan'**
  String get shopperReplacementAutomatic;

  /// No description provided for @shopperReplacementPrices.
  ///
  /// In uz, this message translates to:
  /// **'Bozor narxi {price} · so\'ramasdan {bound} gacha'**
  String shopperReplacementPrices(String price, String bound);

  /// No description provided for @shopperClientNote.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz: «{note}»'**
  String shopperClientNote(String note);

  /// No description provided for @shopperGroupToBuy.
  ///
  /// In uz, this message translates to:
  /// **'Sotib olish'**
  String get shopperGroupToBuy;

  /// No description provided for @shopperGroupWaiting.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz javobini kutyapmiz'**
  String get shopperGroupWaiting;

  /// No description provided for @shopperGroupDone.
  ///
  /// In uz, this message translates to:
  /// **'Tayyor'**
  String get shopperGroupDone;

  /// No description provided for @shopperAskedPrice.
  ///
  /// In uz, this message translates to:
  /// **'Mijozdan so\'raldi: narx chegaradan yuqori. Javob {time} gacha'**
  String shopperAskedPrice(String time);

  /// No description provided for @shopperAskedSubstitution.
  ///
  /// In uz, this message translates to:
  /// **'Mijozdan so\'raldi: almashtirish. Javob {time} gacha'**
  String shopperAskedSubstitution(String time);

  /// No description provided for @shopperAskedQuantity.
  ///
  /// In uz, this message translates to:
  /// **'Mijozdan so\'raldi: kamroq miqdor. Javob {time} gacha'**
  String shopperAskedQuantity(String time);

  /// No description provided for @shopperWaitBuyOthers.
  ///
  /// In uz, this message translates to:
  /// **'Kutayotganda qolganlarini sotib oling.'**
  String get shopperWaitBuyOthers;

  /// No description provided for @shopperQuestionExpired.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz o\'z vaqtida javob bermadi. Operator bu mahsulotni buyurtmadan olib tashlaydi.'**
  String get shopperQuestionExpired;

  /// No description provided for @shopperBoughtAt.
  ///
  /// In uz, this message translates to:
  /// **'{quantity}, {price} dan sotib olindi'**
  String shopperBoughtAt(String quantity, String price);

  /// No description provided for @shopperBoughtInstead.
  ///
  /// In uz, this message translates to:
  /// **'«{name}» o\'rniga · {quantity}, {price} dan'**
  String shopperBoughtInstead(String name, String quantity, String price);

  /// No description provided for @shopperTagReplaced.
  ///
  /// In uz, this message translates to:
  /// **'Almashtirildi'**
  String get shopperTagReplaced;

  /// No description provided for @shopperTagRemoved.
  ///
  /// In uz, this message translates to:
  /// **'Olib tashlandi: {reason}'**
  String shopperTagRemoved(String reason);

  /// No description provided for @doneButton.
  ///
  /// In uz, this message translates to:
  /// **'Tayyor'**
  String get doneButton;

  /// No description provided for @itemColumnProduct.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot'**
  String get itemColumnProduct;

  /// No description provided for @itemColumnQuantity.
  ///
  /// In uz, this message translates to:
  /// **'Miqdor'**
  String get itemColumnQuantity;

  /// No description provided for @itemColumnPrice.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz uchun narx'**
  String get itemColumnPrice;

  /// No description provided for @itemColumnTotal.
  ///
  /// In uz, this message translates to:
  /// **'Summa'**
  String get itemColumnTotal;

  /// No description provided for @itemExpiredHint.
  ///
  /// In uz, this message translates to:
  /// **'Javob muddati tugadi — «Mijozga savollar»ga qarang'**
  String get itemExpiredHint;

  /// No description provided for @historyNewestFirst.
  ///
  /// In uz, this message translates to:
  /// **'yangilari tepada'**
  String get historyNewestFirst;

  /// No description provided for @historyShowAll.
  ///
  /// In uz, this message translates to:
  /// **'Butun tarixni ko\'rsatish ({count})'**
  String historyShowAll(int count);

  /// No description provided for @historyShowFewer.
  ///
  /// In uz, this message translates to:
  /// **'Tarixni yig\'ish'**
  String get historyShowFewer;

  /// No description provided for @dialogOrderLine.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma № {number} · {customer}'**
  String dialogOrderLine(String number, String customer);

  /// No description provided for @pickShopperHint.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'uvchini bosing — buyurtma darhol unga o\'tadi.'**
  String get pickShopperHint;

  /// No description provided for @pickCourierHint.
  ///
  /// In uz, this message translates to:
  /// **'Kuryerni bosing — buyurtma darhol unga o\'tadi.'**
  String get pickCourierHint;

  /// No description provided for @requestCustomerReason.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz sababi: «{reason}»'**
  String requestCustomerReason(String reason);
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
