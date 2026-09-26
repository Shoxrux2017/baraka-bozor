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
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(phoneNationalDigits),
      ],
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
