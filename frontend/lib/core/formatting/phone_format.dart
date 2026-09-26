/// The country code every phone in the service carries
/// (`docs/09-api-contracts.md` section 6).
const String phoneCountryCode = '+998';

/// The number of digits after the country code.
const int phoneNationalDigits = 9;

/// Renders an E.164 phone the way `docs/07-architecture.md` section 27
/// shows it: `+998 90 123 45 67`. Anything that is not such a phone is
/// returned unchanged rather than mangled.
String formatPhone(String e164) {
  if (!e164.startsWith(phoneCountryCode) ||
      e164.length != phoneCountryCode.length + phoneNationalDigits) {
    return e164;
  }
  final String digits = e164.substring(phoneCountryCode.length);
  if (!RegExp(r'^[0-9]+$').hasMatch(digits)) {
    return e164;
  }
  return '$phoneCountryCode ${digits.substring(0, 2)} ${digits.substring(2, 5)} '
      '${digits.substring(5, 7)} ${digits.substring(7)}';
}

/// The E.164 phone for nine national digits, or `null` when [digits] is not
/// exactly nine digits.
String? phoneFromNationalDigits(String digits) {
  if (digits.length != phoneNationalDigits ||
      !RegExp(r'^[0-9]+$').hasMatch(digits)) {
    return null;
  }
  return '$phoneCountryCode$digits';
}
