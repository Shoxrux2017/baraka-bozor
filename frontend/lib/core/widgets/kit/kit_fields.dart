import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../features/shopper/domain/price_guard.dart';
import '../../formatting/money_format.dart';
import '../../formatting/server_text.dart';
import '../../localization/generated/app_localizations.dart';
import '../../localization/interface_language.dart';
import '../../theme/kit_colors.dart';

/// The longest note the server keeps with a question or a line's removal.
const int kitNoteMax = 300;

/// The error of a note over [kitNoteMax] characters as the server counts them.
String? noteTooLong(AppLocalizations l10n, String text) =>
    trimLikeServer(text).runes.length > kitNoteMax
    ? l10n.fieldTooLong(kitNoteMax)
    : null;

OutlineInputBorder _kitFieldBorder(Color? color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(14),
  borderSide: color == null
      ? BorderSide.none
      : BorderSide(color: color, width: 1.5),
);

/// The kit's filled field; [warn] outlines it amber, the mark of the value a
/// question to the Customer is about.
InputDecoration kitFieldDecoration({
  String? hint,
  String? suffix,
  String? helper,
  bool warn = false,
  bool big = false,
}) {
  final Color? outline = warn ? KitColors.warning : null;

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 15, color: KitColors.muted),
    suffixText: suffix,
    suffixStyle: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: KitColors.muted,
    ),
    helperText: helper,
    helperMaxLines: 4,
    helperStyle: const TextStyle(fontSize: 12, color: KitColors.muted),
    filled: true,
    fillColor: KitColors.field,
    constraints: big ? const BoxConstraints(minHeight: 58) : null,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: _kitFieldBorder(outline),
    enabledBorder: _kitFieldBorder(outline),
    disabledBorder: _kitFieldBorder(outline),
    focusedBorder: _kitFieldBorder(outline ?? KitColors.primary),
    errorBorder: _kitFieldBorder(KitColors.danger),
    focusedErrorBorder: _kitFieldBorder(KitColors.danger),
  );
}

const TextStyle kitBigFieldStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w700,
  color: KitColors.ink,
);

/// A field under its [label].
class KitLabeledField extends StatelessWidget {
  const KitLabeledField({required this.label, required this.field, super.key});

  final String label;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: KitColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}

/// Groups the digits of a price by three from the right with spaces as the
/// Shopper types, and keeps the cursor at the end.
class _GroupedDigitsFormatter extends TextInputFormatter {
  const _GroupedDigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final StringBuffer grouped = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        grouped.write(' ');
      }
      grouped.write(digits[i]);
    }
    final String text = grouped.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// A price field in sum, digits only, with the groups spaced as typed; the
/// kit's field with its [label] above. [warn] outlines it amber.
class PriceField extends StatelessWidget {
  const PriceField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.required,
    required this.enabled,
    this.helper,
    this.warn = false,
    this.validator,
    super.key,
  });

  final String fieldKey;
  final TextEditingController controller;
  final String label;
  final bool required;
  final bool enabled;
  final String? helper;
  final bool warn;

  /// Replaces the price check when given.
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return KitLabeledField(
      label: label,
      field: TextFormField(
        key: ValueKey<String>(fieldKey),
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        style: kitBigFieldStyle,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
          LengthLimitingTextInputFormatter(14),
          const _GroupedDigitsFormatter(),
        ],
        decoration: kitFieldDecoration(
          suffix: MoneyFormat.currency(interfaceLanguage(context)),
          helper: helper,
          warn: warn,
          big: true,
        ),
        validator:
            validator ??
            (String? text) {
              final String value = (text ?? '').trim();
              if (value.isEmpty) {
                return required ? l10n.fieldRequired : null;
              }
              return parsePrice(value) == null ? l10n.fieldMarketPrice : null;
            },
      ),
    );
  }
}

/// An optional note of up to 300 characters under its [label], with how many
/// it holds.
class KitNoteField extends StatelessWidget {
  const KitNoteField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.hint,
    required this.enabled,
    this.validator,
    super.key,
  });

  final String fieldKey;
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool enabled;

  /// Replaces the length check when given.
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        KitLabeledField(
          label: label,
          field: TextFormField(
            key: ValueKey<String>(fieldKey),
            controller: controller,
            enabled: enabled,
            minLines: 1,
            maxLines: 3,
            style: const TextStyle(fontSize: 15, color: KitColors.ink),
            decoration: kitFieldDecoration(hint: hint),
            validator:
                validator ?? (String? text) => noteTooLong(l10n, text ?? ''),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: ListenableBuilder(
            listenable: controller,
            builder: (BuildContext context, Widget? _) {
              final int kept = trimLikeServer(controller.text).runes.length;

              return Text(
                '$kept / $kitNoteMax',
                style: TextStyle(
                  fontSize: 12,
                  color: kept > kitNoteMax ? KitColors.danger : KitColors.muted,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
