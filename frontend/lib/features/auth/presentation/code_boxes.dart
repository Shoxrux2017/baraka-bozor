import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/shake.dart';

/// The number of digits in a login code (`docs/09-api-contracts.md`
/// section 6).
const int loginCodeLength = 6;

/// How the six boxes look (`DL-139`): typing, a pulse while the code is
/// checked, red when it was wrong, green when it was right.
enum CodeBoxesLook { entry, checking, wrong, right }

/// The six boxes of the Telegram code (screen 04 of `kit/01-vhod`).
///
/// One hidden text field takes the typing, the one-time-code autofill and a
/// paste (digits only, at most six); the boxes only draw what it holds, with
/// a blinking caret in the next empty box. A new digit pops in; [look] colours
/// the boxes, pulses them while checking, and refuses input while they are
/// red; [misses] shakes them. The reader gets one stop that says how many
/// digits are in and which. It is a form field: a code that is not six digits
/// reports [invalidMessage] under the boxes.
class CodeBoxes extends StatefulWidget {
  const CodeBoxes({
    required this.controller,
    required this.invalidMessage,
    this.onSubmitted,
    this.enabled = true,
    this.look = CodeBoxesLook.entry,
    this.misses = 0,
    this.onCompleted,
    this.spokenLabel,
    super.key,
  });

  final TextEditingController controller;
  final String invalidMessage;
  final VoidCallback? onSubmitted;

  /// Off while the phone is locked: nothing can be typed or submitted.
  final bool enabled;

  /// How the boxes look; while it is [CodeBoxesLook.wrong] the field refuses
  /// edits and keeps its focus.
  final CodeBoxesLook look;

  /// Grows by one with each wrong code; every step shakes the boxes.
  final int misses;

  /// Called once each time the text reaches six digits from fewer; the flag
  /// is true when the sixth digit came with others in one edit (a paste).
  final ValueChanged<bool>? onCompleted;

  /// What the reader says first; the label of the code by default.
  final String? spokenLabel;

  @override
  State<CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<CodeBoxes> with TickerProviderStateMixin {
  static const double _gap = 8;
  static const double _boxWidth = 44;
  static const double _boxHeight = 52;
  static const Curve _popCurve = Cubic(0.2, 0.8, 0.2, 1);

  final FocusNode _focus = FocusNode();

  /// Flips the caret every 530 ms while it blinks. A timer, not a ticker: it
  /// only changes paint state, so `pumpAndSettle` still settles.
  Timer? _blink;
  bool _caretOn = true;

  /// The digit pop: 180 ms.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  /// The checking pulse: 1 s there and 1 s back.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  int _length = 0;
  int _popFrom = 0;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _length = widget.controller.text.length;
    _focus.addListener(_onFocus);
    widget.controller.addListener(_onText);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _syncTickers();
  }

  @override
  void didUpdateWidget(CodeBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
      _length = widget.controller.text.length;
    }
    _syncTickers();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    _blink?.cancel();
    _pop.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onFocus() {
    _syncTickers();
    setState(() {});
  }

  void _onText() {
    final int before = _length;
    final int now = widget.controller.text.length;
    _length = now;
    if (_blink != null) {
      _caretOn = true;
      _restartBlink();
    }
    if (now > before && !_reduced) {
      _popFrom = before;
      _pop.forward(from: 0);
    }
    setState(() {});
    if (now == loginCodeLength && before < loginCodeLength) {
      widget.onCompleted?.call(now - before > 1);
    }
  }

  void _restartBlink() {
    _blink?.cancel();
    _blink = Timer.periodic(const Duration(milliseconds: 530), (Timer _) {
      setState(() => _caretOn = !_caretOn);
    });
  }

  void _syncTickers() {
    final bool blink =
        _focus.hasFocus &&
        widget.enabled &&
        widget.look == CodeBoxesLook.entry &&
        !_reduced;
    if (blink && _blink == null) {
      _caretOn = true;
      _restartBlink();
    } else if (!blink && _blink != null) {
      _blink!.cancel();
      _blink = null;
      _caretOn = true;
    }
    final bool pulse = widget.look == CodeBoxesLook.checking && !_reduced;
    if (pulse && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!pulse && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String code = widget.controller.text;
    final String spokenValue = code.isEmpty
        ? l10n.codeEmptySpoken
        : l10n.codeEnteredSpoken(code.length, code.split('').join(' '));

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
                return Semantics(
                  key: const ValueKey<String>('code-semantics'),
                  container: true,
                  textField: true,
                  enabled: widget.enabled,
                  focused: _focus.hasFocus,
                  label: widget.spokenLabel ?? l10n.codeLabel,
                  value: spokenValue,
                  onTap: widget.enabled ? _focus.requestFocus : null,
                  child: Shake(
                    trigger: widget.misses,
                    child: Stack(
                      children: <Widget>[
                        ExcludeSemantics(
                          child: AnimatedBuilder(
                            animation: Listenable.merge(<Listenable>[
                              _pop,
                              _pulse,
                            ]),
                            builder: (BuildContext context, Widget? _) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  for (
                                    int i = 0;
                                    i < loginCodeLength;
                                    i++
                                  ) ...<Widget>[
                                    if (i > 0) const SizedBox(width: _gap),
                                    _box(i, code, width, field.hasError),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                        Positioned.fill(
                          child: TextSelectionTheme(
                            data: const TextSelectionThemeData(
                              cursorColor: Colors.transparent,
                              selectionColor: Colors.transparent,
                              selectionHandleColor: Colors.transparent,
                            ),
                            child: ExcludeSemantics(
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
                                  _RefuseWhenWrong(
                                    () => widget.look == CodeBoxesLook.wrong,
                                  ),
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
                    ),
                  ),
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

  Widget _box(int i, String code, double width, bool failed) {
    final bool popping =
        _pop.isAnimating && i >= _popFrom && i < code.length && !_reduced;
    final double eased = _popCurve.transform(_pop.value);
    final bool focused = _focus.hasFocus;
    return _Box(
      key: ValueKey<String>('code-box-$i'),
      width: width,
      height: _boxHeight,
      digit: i < code.length ? code[i] : null,
      caret: focused && i == code.length,
      caretOn: _caretOn,
      highlighted: i < code.length || (focused && i == code.length),
      failed: failed,
      look: widget.look,
      pulse: widget.look == CodeBoxesLook.checking
          ? Curves.easeInOut.transform(_pulse.value)
          : 0,
      popScale: popping ? 0.55 + 0.45 * eased : null,
      popOpacity: popping ? 0.2 + 0.8 * eased : 1,
    );
  }
}

/// Returns the old value while [refusing] is true, so the field keeps its
/// focus and the keyboard but takes no edit.
class _RefuseWhenWrong extends TextInputFormatter {
  const _RefuseWhenWrong(this.refusing);

  final bool Function() refusing;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => refusing() ? oldValue : newValue;
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
    required this.caretOn,
    required this.highlighted,
    required this.failed,
    required this.look,
    required this.pulse,
    required this.popScale,
    required this.popOpacity,
    super.key,
  });

  final double width;
  final double height;
  final String? digit;
  final bool caret;
  final bool caretOn;
  final bool highlighted;
  final bool failed;
  final CodeBoxesLook look;

  /// 0 … 1 along the checking pulse.
  final double pulse;

  /// Null when the digit is not popping.
  final double? popScale;
  final double popOpacity;

  @override
  Widget build(BuildContext context) {
    final bool wrong = look == CodeBoxesLook.wrong;
    final bool right = look == CodeBoxesLook.right;
    final bool checking = look == CodeBoxesLook.checking;
    final Color fill = wrong
        ? KitColors.dangerWash
        : right
        ? KitColors.primaryWash
        : checking
        ? Color.lerp(KitColors.field, KitColors.primaryWash, pulse)!
        : KitColors.field;
    final Color edge = wrong || failed
        ? KitColors.danger
        : right
        ? KitColors.primary
        : checking
        ? Color.lerp(KitColors.line, KitColors.pulseEdge, pulse)!
        : highlighted
        ? KitColors.primary
        : KitColors.line;
    final bool thick = wrong || right || (highlighted && !checking);
    final String? digit = this.digit;
    Widget? content;
    if (digit != null) {
      content = FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          digit,
          style: TextStyle(
            fontFamily: appFontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: right ? KitColors.primaryDark : KitColors.ink,
          ),
        ),
      );
      final double? scale = popScale;
      if (scale != null) {
        content = Opacity(
          opacity: popOpacity,
          child: Transform.scale(scale: scale, child: content),
        );
      }
    } else if (caret && caretOn) {
      content = Container(
        key: const ValueKey<String>('code-caret'),
        width: 2,
        height: 26,
        color: KitColors.primary,
      );
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: edge, width: thick ? 1.5 : 1),
      ),
      alignment: Alignment.center,
      child: content,
    );
  }
}
