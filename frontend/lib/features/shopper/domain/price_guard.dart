/// The typo guard of `DL-3` S-35 (`docs/04` section 12, `DL-54` (20)): a
/// price paid more than three times the market price of the product bought,
/// or less than a third of it, is more likely a slip of the finger than the
/// stall's price, so the Shopper confirms it before it is sent. The server's
/// bounds apply whatever the Shopper confirms.
bool looksMistyped(int price, int marketPrice) =>
    price > marketPrice * 3 || price * 3 < marketPrice;

/// A price as the Shopper types it — digits, with spaces between the
/// groups — or `null` when it is no whole number of sum from 1 to
/// 1 000 000 000, the catalog's own range (`DL-20` (6)).
int? parsePrice(String text) {
  final String digits = text.replaceAll(RegExp(r'[\s ]'), '');
  if (!RegExp(r'^\d{1,10}$').hasMatch(digits)) {
    return null;
  }
  final int price = int.parse(digits);
  return price >= 1 && price <= 1000000000 ? price : null;
}
