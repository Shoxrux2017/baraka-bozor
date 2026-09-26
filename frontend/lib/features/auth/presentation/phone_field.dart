import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';

/// The phone entry of every login: the country code is fixed and shown, the
/// person types the nine national digits, and the value sent is the E.164
/// form the API requires (`docs/09-api-contracts.md` section 6). Nothing
/// else is normalized.
class PhoneField extends StatelessWidget {
  const PhoneField({
    required this.controller,
    this.autofocus = false,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final bool autofocus;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// The E.164 phone in [controller], or `null` while it is incomplete.
  static String? phoneOf(TextEditingController controller) =>
      phoneFromNationalDigits(controller.text);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return TextFormField(
      key: const ValueKey<String>('phone-field'),
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      autofillHints: const <String>[AutofillHints.telephoneNumberNational],
      inputFormatters: <TextInputFormatter>[NationalPhoneDigitsFormatter()],
      decoration: InputDecoration(
        labelText: l10n.phoneLabel,
        prefixText: '$phoneCountryCode ',
        hintText: l10n.phoneHint,
      ),
      validator: (String? value) => phoneFromNationalDigits(value ?? '') == null
          ? l10n.phoneInvalid
          : null,
      onFieldSubmitted: onSubmitted,
    );
  }
}

/// Keeps the nine national digits of whatever was typed, pasted or filled
/// in. A full number with the country code — `+998 90 123 45 67`, with or
/// without the plus — loses its `998`, so a paste does not end up as a
/// nine-digit number starting with the country code; anything longer than
/// nine digits is cut.
class NationalPhoneDigitsFormatter extends TextInputFormatter {
  static final RegExp _notDigits = RegExp(r'[^0-9]');
  static const String _countryDigits = '998';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(_notDigits, '');
    if (digits.length > phoneNationalDigits &&
        digits.startsWith(_countryDigits)) {
      digits = digits.substring(_countryDigits.length);
    }
    if (digits.length > phoneNationalDigits) {
      digits = digits.substring(0, phoneNationalDigits);
    }
    if (digits == newValue.text) {
      return newValue;
    }
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
