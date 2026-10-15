import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The licence that ships with the bundled Montserrat font.
const String montserratLicenseAsset = 'assets/fonts/Montserrat-OFL.txt';

/// Puts the bundled font's licence on the app's licences page: the SIL Open
/// Font License requires its notice to travel with the font.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(<String>[
      'Montserrat',
    ], await rootBundle.loadString(montserratLicenseAsset));
  });
}
