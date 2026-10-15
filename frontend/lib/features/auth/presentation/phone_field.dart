import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';

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
      phoneFromNationalDigits(_digitsOf(controller.text));

  static String _digitsOf(String text) => text.replaceAll(' ', '');

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
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: KitColors.ink,
      ),
      decoration: InputDecoration(
        hintText: l10n.phoneHint,
        hintStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          color: KitColors.muted,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        prefixIconConstraints: const BoxConstraints(),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 20, right: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                phoneCountryCode,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 22, color: KitColors.line),
            ],
          ),
        ),
        prefixIconColor: KitColors.ink,
      ),
      validator: (String? value) =>
          phoneFromNationalDigits(_digitsOf(value ?? '')) == null
          ? l10n.phoneInvalid
          : null,
      onFieldSubmitted: onSubmitted,
    );
  }
}

/// Keeps the nine national digits of whatever was typed, pasted or filled
/// in, and shows them grouped as `90 123 45 67`. A full number with the
/// country code — `+998 90 123 45 67`, with or without the plus — loses its
/// `998`, so a paste does not end up as a nine-digit number starting with the
/// country code; anything longer than nine digits is cut. The cursor stays
/// after the digit it was after; a backspace over a gap removes the digit
/// before it.
class NationalPhoneDigitsFormatter extends TextInputFormatter {
  static final RegExp _notDigits = RegExp(r'[^0-9]');
  static const String _countryDigits = '998';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String typed = newValue.text.replaceAll(_notDigits, '');
    String digits = typed;
    if (digits.length > phoneNationalDigits &&
        digits.startsWith(_countryDigits)) {
      digits = digits.substring(_countryDigits.length);
    }
    if (digits.length > phoneNationalDigits) {
      digits = digits.substring(0, phoneNationalDigits);
    }

    final int cursor = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, newValue.text.length)
        : newValue.text.length;
    int digitsBefore = digits == typed
        ? newValue.text.substring(0, cursor).replaceAll(_notDigits, '').length
        : digits.length;

    // The gap itself was deleted: the digits are as they were, so the digit
    // before the cursor goes instead.
    if (digitsBefore > 0 &&
        _deletedAGap(oldValue.text, newValue.text, cursor)) {
      digits =
          digits.substring(0, digitsBefore - 1) +
          digits.substring(digitsBefore);
      digitsBefore -= 1;
    }

    final String grouped = groupNationalDigits(digits);
    if (grouped == newValue.text) {
      return newValue;
    }
    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(
        offset: _offsetAfter(digitsBefore, grouped),
      ),
    );
  }

  /// Whether [next] is [previous] with the single space at [cursor] removed.
  static bool _deletedAGap(String previous, String next, int cursor) =>
      previous.length == next.length + 1 &&
      cursor < previous.length &&
      previous[cursor] == ' ' &&
      previous.replaceRange(cursor, cursor + 1, '') == next;

  /// The offset in [grouped] right after its [count]-th digit.
  static int _offsetAfter(int count, String grouped) {
    if (count <= 0) {
      return 0;
    }
    int seen = 0;
    for (int i = 0; i < grouped.length; i++) {
      if (grouped[i] != ' ') {
        seen++;
        if (seen == count) {
          return i + 1;
        }
      }
    }
    return grouped.length;
  }
}
