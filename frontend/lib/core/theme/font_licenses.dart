import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The licence that ships with the bundled Manrope font.
const String manropeLicenseAsset = 'assets/fonts/Manrope-OFL.txt';

/// Puts the bundled font's licence on the app's licences page: the SIL Open
/// Font License requires its notice to travel with the font.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(<String>[
      'Manrope',
    ], await rootBundle.loadString(manropeLicenseAsset));
  });
}
