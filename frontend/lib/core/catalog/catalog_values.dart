/// The machine values every catalog screen shares — the Admin's in the
/// panel and the Customer's in the app — as `docs/08-database.md` section 7
/// names them. Labels come from the localized strings, never from these.
enum UnitCode {
  kg('kg'),
  gram('gram'),
  piece('piece'),
  liter('liter'),
  package('package'),
  box('box'),
  bundle('bundle'),
  meter('meter');

  const UnitCode(this.code);

  final String code;

  static UnitCode? tryParse(String code) {
    for (final UnitCode unit in values) {
      if (unit.code == code) {
        return unit;
      }
    }
    return null;
  }
}

/// Whether the price shown is what the Customer pays (`fixed`) or an
/// estimate the Shopper's receipt settles (`estimate`, `BR-PRICE-003`).
enum PriceMode {
  fixed('fixed'),
  estimate('estimate');

  const PriceMode(this.code);

  final String code;

  static PriceMode? tryParse(String code) {
    for (final PriceMode mode in values) {
      if (mode.code == code) {
        return mode;
      }
    }
    return null;
  }
}
