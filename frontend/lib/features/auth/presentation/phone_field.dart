import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';

/// The phone entry of every login: the country code is fixed and shown, the
/// person types the nine national digits, and the value sent is the E.164
/// form the API requires (`docs/09-api-contracts.md` section 6). Nothing
/// else is normalized.
///
/// The Customer's page (`DL-139`) draws a [label] above the field, bold
/// digits ([strong]), a × that clears it ([clearable]) and checks the count
/// itself ([validate] off); the staff panel keeps the plain field.
class PhoneField extends StatefulWidget {
  const PhoneField({
    required this.controller,
    this.autofocus = false,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.label,
    this.clearable = false,
    this.strong = false,
    this.validate = true,
    this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final bool autofocus;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// Drawn above the field; with the country code it is also what a screen
  /// reader calls the field.
  final String? label;

  /// Shows a × while the field has text; it clears the field and keeps focus.
  final bool clearable;

  /// Typed digits 14 w600 with letter spacing, the example light.
  final bool strong;

  /// Whether the form refuses a number of fewer than nine digits.
  final bool validate;

  /// The field's focus, when the page needs to follow or move it.
  final FocusNode? focusNode;

  /// The E.164 phone in [controller], or `null` while it is incomplete.
  static String? phoneOf(TextEditingController controller) =>
      phoneFromNationalDigits(_digitsOf(controller.text));

  static String _digitsOf(String text) => text.replaceAll(' ', '');

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  FocusNode? _ownNode;

  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  void _clear() {
    widget.controller.clear();
    _node.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? label = widget.label;
    final bool strong = widget.strong;

    final Widget field = ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? _) {
        final Widget prefix = Padding(
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
        );
        return TextFormField(
          key: const ValueKey<String>('phone-field'),
          controller: widget.controller,
          focusNode: _node,
          autofocus: widget.autofocus,
          keyboardType: TextInputType.phone,
          textInputAction: widget.textInputAction,
          autofillHints: const <String>[
            AutofillHints.telephoneNumber,
            AutofillHints.telephoneNumberNational,
          ],
          inputFormatters: <TextInputFormatter>[NationalPhoneDigitsFormatter()],
          style: TextStyle(
            fontSize: 14,
            fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: strong ? 0.3 : null,
            color: KitColors.ink,
          ),
          decoration: InputDecoration(
            // The example is a hint widget, so no reader says it as if it
            // were the number.
            hint: ExcludeSemantics(
              child: Text(
                l10n.phoneHint,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: strong ? FontWeight.w400 : FontWeight.w500,
                  color: KitColors.muted,
                ),
              ),
            ),
            contentPadding:
                Theme.of(context).inputDecorationTheme.contentPadding ??
                const EdgeInsets.symmetric(vertical: 18),
            prefixIconConstraints: const BoxConstraints(),
            // With a label the reader hears the code in the field's name.
            prefixIcon: label == null
                ? prefix
                : ExcludeSemantics(child: prefix),
            prefixIconColor: KitColors.ink,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            suffixIcon: widget.clearable && widget.controller.text.isNotEmpty
                ? IconButton(
                    key: const ValueKey<String>('phone-clear'),
                    onPressed: _clear,
                    tooltip: l10n.phoneClear,
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    icon: const Icon(
                      Icons.cancel,
                      size: 20,
                      color: KitColors.muted,
                    ),
                  )
                : null,
          ),
          validator: widget.validate
              ? (String? value) =>
                    phoneFromNationalDigits(
                          PhoneField._digitsOf(value ?? ''),
                        ) ==
                        null
                    ? l10n.phoneInvalid
                    : null
              : null,
          onFieldSubmitted: widget.onSubmitted,
        );
      },
    );

    if (label == null) {
      return field;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: ExcludeSemantics(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: KitColors.ink2,
              ),
            ),
          ),
        ),
        // The count rides on the field's own reader stop as its hint.
        ListenableBuilder(
          listenable: widget.controller,
          builder: (BuildContext context, Widget? _) {
            final int digits = PhoneField._digitsOf(widget.controller.text)
                .length;
            return Semantics(
              label: '$label, $phoneCountryCode',
              hint: digits == 0 ? null : l10n.phoneEnteredSpoken(digits),
              child: field,
            );
          },
        ),
      ],
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
