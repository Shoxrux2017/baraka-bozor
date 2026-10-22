import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';

/// A password field of the sign-in screens, with the eye that shows or hides
/// what was typed.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    this.fieldKey,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.autofocus = false,
    this.autofillHint = AutofillHints.password,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final Key? fieldKey;

  /// Shown above the field.
  final String? label;

  /// Shown inside the empty field, for a field that has no label above it.
  final String? hintText;
  final String? helperText;

  /// Shown under the field in place of the validator's, when the server
  /// refused the value.
  final String? errorText;
  final bool autofocus;
  final String autofillHint;
  final TextInputAction textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? label = widget.label;
    final double vertical =
        Theme.of(context).inputDecorationTheme.contentPadding
            ?.resolve(Directionality.of(context))
            .top ??
        18;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: KitColors.ink2,
              ),
            ),
          ),
        TextFormField(
          key: widget.fieldKey,
          controller: widget.controller,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          obscureText: _hidden,
          autofillHints: <String>[widget.autofillHint],
          textInputAction: widget.textInputAction,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              color: KitColors.muted,
            ),
            helperText: widget.helperText,
            helperStyle: const TextStyle(fontSize: 11, color: KitColors.muted),
            errorText: widget.errorText,
            contentPadding: EdgeInsets.fromLTRB(20, vertical, 8, vertical),
            suffixIcon: IconButton(
              key: const ValueKey<String>('password-eye'),
              tooltip: _hidden ? l10n.showPassword : l10n.hidePassword,
              onPressed: () => setState(() => _hidden = !_hidden),
              icon: Icon(
                _hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 22,
              ),
            ),
          ),
          validator: widget.validator,
          onFieldSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}
