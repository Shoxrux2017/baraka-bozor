import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/kit_colors.dart';

/// The number of digits in a login code (`docs/09-api-contracts.md`
/// section 6).
const int loginCodeLength = 6;

/// The six boxes of the Telegram code (screen 04 of `kit/01-vhod`).
///
/// One hidden text field takes the typing, the one-time-code autofill and a
/// paste (digits only, at most six); the boxes only draw what it holds, with
/// a caret in the next empty box. The box in focus and the filled ones have a
/// green outline. It is a form field: a code that is not six digits reports
/// [invalidMessage] under the boxes.
class CodeBoxes extends StatefulWidget {
  const CodeBoxes({
    required this.controller,
    required this.invalidMessage,
    this.onSubmitted,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final String invalidMessage;
  final VoidCallback? onSubmitted;

  /// Off while the phone is locked: nothing can be typed or submitted.
  final bool enabled;

  @override
  State<CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<CodeBoxes> {
  static const double _gap = 8;
  static const double _boxWidth = 44;
  static const double _boxHeight = 52;

  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_redraw);
    widget.controller.addListener(_redraw);
  }

  @override
  void didUpdateWidget(CodeBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_redraw);
      widget.controller.addListener(_redraw);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_redraw);
    _focus
      ..removeListener(_redraw)
      ..dispose();
    super.dispose();
  }

  void _redraw() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String code = widget.controller.text;

    return FormField<String>(
      key: const ValueKey<String>('code-boxes'),
      initialValue: '',
      validator: (String? _) => widget.controller.text.length == loginCodeLength
          ? null
          : widget.invalidMessage,
      builder: (FormFieldState<String> field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width =
                    ((constraints.maxWidth - _gap * (loginCodeLength - 1)) /
                            loginCodeLength)
                        .clamp(0, _boxWidth);
                return Stack(
                  children: <Widget>[
                    ExcludeSemantics(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          for (int i = 0; i < loginCodeLength; i++) ...<Widget>[
                            if (i > 0) const SizedBox(width: _gap),
                            _Box(
                              width: width,
                              height: _boxHeight,
                              digit: i < code.length ? code[i] : null,
                              caret: _focus.hasFocus && i == code.length,
                              highlighted:
                                  i < code.length ||
                                  (_focus.hasFocus && i == code.length),
                              failed: field.hasError,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned.fill(
                      child: TextSelectionTheme(
                        data: const TextSelectionThemeData(
                          cursorColor: Colors.transparent,
                          selectionColor: Colors.transparent,
                          selectionHandleColor: Colors.transparent,
                        ),
                        child: Semantics(
                          label: l10n.codeLabel,
                          child: TextField(
                            key: const ValueKey<String>('code-field'),
                            controller: widget.controller,
                            focusNode: _focus,
                            enabled: widget.enabled,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            autofillHints: const <String>[
                              AutofillHints.oneTimeCode,
                            ],
                            autocorrect: false,
                            enableSuggestions: false,
                            showCursor: false,
                            inputFormatters: <TextInputFormatter>[
                              LoginCodeDigitsFormatter(),
                            ],
                            style: const TextStyle(
                              color: Colors.transparent,
                              fontSize: 1,
                            ),
                            decoration: const InputDecoration(
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: field.didChange,
                            onSubmitted: (String _) =>
                                widget.onSubmitted?.call(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (field.hasError)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    field.errorText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: KitColors.danger,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Keeps the digits of a login code, at most [loginCodeLength]. A paste of a
/// whole code (six or more digits inserted at once) replaces what was typed
/// before it, so a code pasted into a partly filled field is not cut off by
/// the digits already there.
class LoginCodeDigitsFormatter extends TextInputFormatter {
  static final RegExp _notDigits = RegExp(r'[^0-9]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(_notDigits, '');
    if (digits.length > loginCodeLength) {
      final int inserted = newValue.text.length - oldValue.text.length;
      final int cursor = newValue.selection.isValid
          ? newValue.selection.extentOffset.clamp(0, newValue.text.length)
          : newValue.text.length;
      final String pasted = inserted > 0
          ? newValue.text
                .substring((cursor - inserted).clamp(0, cursor), cursor)
                .replaceAll(_notDigits, '')
          : '';
      digits = pasted.length >= loginCodeLength ? pasted : digits;
      digits = digits.substring(0, loginCodeLength);
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

class _Box extends StatelessWidget {
  const _Box({
    required this.width,
    required this.height,
    required this.digit,
    required this.caret,
    required this.highlighted,
    required this.failed,
  });

  final double width;
  final double height;
  final String? digit;
  final bool caret;
  final bool highlighted;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final String? digit = this.digit;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: KitColors.field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: failed
              ? KitColors.danger
              : highlighted
              ? KitColors.primary
              : KitColors.line,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: digit != null
          ? FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                digit,
                style: const TextStyle(
                  fontFamily: appFontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: KitColors.ink,
                ),
              ),
            )
          : caret
          ? Container(width: 2, height: 26, color: KitColors.primary)
          : null,
    );
  }
}
