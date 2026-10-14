import 'package:baraka_bozor/core/theme/font_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled Manrope file is a font Flutter can load', () async {
    final FontLoader loader = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf'));
    await loader.load();
  });

  test('the font licence (SIL OFL 1.1) is on the licences page', () async {
    registerFontLicenses();
    final List<LicenseEntry> entries = await LicenseRegistry.licenses.toList();
    final LicenseEntry manrope = entries.singleWhere(
      (LicenseEntry entry) => entry.packages.contains('Manrope'),
    );
    expect(
      manrope.paragraphs.map((LicenseParagraph p) => p.text).join('\n'),
      contains('SIL OPEN FONT LICENSE'),
    );
  });
}
