import '../catalog/catalog_values.dart';
import 'generated/app_localizations.dart';

/// The words for the catalog's machine values, in the interface language.
abstract final class CatalogLabels {
  static String unit(AppLocalizations l10n, UnitCode unit) => switch (unit) {
    UnitCode.kg => l10n.unitKg,
    UnitCode.gram => l10n.unitGram,
    UnitCode.piece => l10n.unitPiece,
    UnitCode.liter => l10n.unitLiter,
    UnitCode.package => l10n.unitPackage,
    UnitCode.box => l10n.unitBox,
    UnitCode.bundle => l10n.unitBundle,
    UnitCode.meter => l10n.unitMeter,
  };

  static String priceMode(AppLocalizations l10n, PriceMode mode) =>
      switch (mode) {
        PriceMode.fixed => l10n.priceModeFixed,
        PriceMode.estimate => l10n.priceModeEstimate,
      };
}
