import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/submit_button.dart';
import '../../legal/application/legal_providers.dart';
import '../../legal/presentation/consent_line.dart';
import '../application/code_login_controller.dart';
import '../data/phone_number_hint.dart';
import 'auth_notice.dart';
import 'auth_scaffold.dart';
import 'lock_message.dart';
import 'phone_field.dart';

/// Step 1 of `docs/04-user-flows.md` section 2 (screen 02 of
/// `kit/01-vhod`): the Customer's phone. «Получить код» asks for the code at
/// once; there is no read-back window (`DL-139`, `vhod-3`).
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  late final TextEditingController _phone;
  final FocusNode _focus = FocusNode();
  final GlobalKey _buttonKey = GlobalKey();

  static const Duration _ownNumberDelay = Duration(milliseconds: 400);

  /// The own-number sheet is asked once in this page's life.
  bool _askedForOwnNumber = false;

  /// The wait between the first focus and the ask, so the sheet never lands
  /// on the launch curtain (`DL-139`).
  Timer? _ownNumberWait;

  /// How many digits the last tap on the grey button said were missing; null
  /// while nothing is said.
  int? _missing;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    final String? phone = ref.read(codeLoginControllerProvider).phone;
    _phone = TextEditingController(
      text: phone == null
          ? ''
          : groupNationalDigits(phone.substring(phoneCountryCode.length)),
    );
    _lastText = _phone.text;
    _phone.addListener(_onEdit);
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _ownNumberWait?.cancel();
    _focus.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Any edit hides the words about the missing digits and a shown refusal
  /// of the request, so «Повторить» can only repeat the number on screen.
  void _onEdit() {
    if (_phone.text == _lastText) {
      return;
    }
    _lastText = _phone.text;
    final CodeLoginState state = ref.read(codeLoginControllerProvider);
    if (state.failure != null &&
        state.failedAction == CodeLoginAction.request) {
      ref.read(codeLoginControllerProvider.notifier).clearFailure();
    }
    if (_missing != null) {
      setState(() => _missing = null);
    }
  }

  void _onFocus() {
    if (_focus.hasFocus && !_askedForOwnNumber && _phone.text.isEmpty) {
      _askedForOwnNumber = true;
      _ownNumberWait = Timer(_ownNumberDelay, _askForOwnNumber);
    }
  }

  /// Asks only if the page is still here, current, focused and the field
  /// still empty after the wait.
  Future<void> _askForOwnNumber() async {
    if (!mounted ||
        !_focus.hasFocus ||
        _phone.text.isNotEmpty ||
        !(ModalRoute.isCurrentOf(context) ?? true)) {
      return;
    }
    final String? digits = await ref.read(phoneNumberHintProvider).request();
    if (!mounted || digits == null || _phone.text.isNotEmpty) {
      return;
    }
    _phone.value = NationalPhoneDigitsFormatter().formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      ),
    );
  }

  int get _digits => _phone.text.replaceAll(' ', '').length;

  /// A failed read of the documents is tried again on a tap, so the consent
  /// line can still appear on this screen.
  void _readDocumentsAgain() {
    if (ref.read(legalIndexProvider).hasError) {
      ref.invalidate(legalIndexProvider);
    }
  }

  /// A tap on the grey button or the keyboard's Done with too few digits.
  void _sayMissing() {
    _readDocumentsAgain();
    final int missing = phoneNationalDigits - _digits;
    if (missing <= 0) {
      return;
    }
    setState(() => _missing = missing);
    announce(context, AppLocalizations.of(context).phoneDigitsLeft(missing));
  }

  Future<void> _submit() async {
    final String? phone = PhoneField.phoneOf(_phone);
    if (phone == null) {
      _sayMissing();
      return;
    }
    _readDocumentsAgain();
    final CodeLoginState state = ref.read(codeLoginControllerProvider);
    if (state.busy || (state.locked && state.phone == phone)) {
      return;
    }
    _afterRequest(
      await ref.read(codeLoginControllerProvider.notifier).requestCode(phone),
    );
  }

  Future<void> _retry() async {
    _afterRequest(await ref.read(codeLoginControllerProvider.notifier).retry());
  }

  /// Only the request that is still current reports success, and the screen
  /// may have gone while it ran.
  void _afterRequest(bool sent) {
    if (!sent || !mounted) {
      return;
    }
    final CodeLoginState state = ref.read(codeLoginControllerProvider);
    final String? phone = state.phone;
    if (phone != null) {
      final AppLocalizations l10n = AppLocalizations.of(context);
      final String shown = formatPhone(phone);
      announce(context, switch (state.requested?.channel) {
        'telegram' => l10n.codeSentSpoken(shown),
        'sms' => l10n.codeSentSmsSpoken(shown),
        _ => l10n.codeSentOtherSpoken(shown),
      });
    }
    context.go(AppPaths.customerCode);
  }

  void _onNotice(AuthNoticeAction action) {
    switch (action) {
      case AuthNoticeAction.retry:
        _retry();
      case AuthNoticeAction.otherNumber:
        _phone.clear();
        _focus.requestFocus();
        ref.read(codeLoginControllerProvider.notifier).clearFailure();
      case AuthNoticeAction.changeNumber || AuthNoticeAction.newCode:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CodeLoginState state = ref.watch(codeLoginControllerProvider);
    final AuthNoticeView? notice = _noticeOf(l10n, state);

    return AuthScaffold(
      title: l10n.customerLoginTitle,
      subtitle: l10n.customerLoginIntro,
      keepVisible: _buttonKey,
      child: AutofillGroup(
        child: ListenableBuilder(
          listenable: _phone,
          builder: (BuildContext context, Widget? _) {
            final String? phone = PhoneField.phoneOf(_phone);
            // The lock belongs to one phone: it holds only while that number
            // is the one typed.
            final bool sameNumber = phone != null && phone == state.phone;
            final bool locked = state.locked && sameNumber;
            final int missing = phoneNationalDigits - _digits;
            final SubmitFace face = state.running == CodeLoginAction.request
                ? SubmitFace.busy
                : state.busy || missing > 0 || locked
                ? SubmitFace.off
                : SubmitFace.ready;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PhoneField(
                  controller: _phone,
                  focusNode: _focus,
                  label: l10n.phoneLabel,
                  autofocus: true,
                  clearable: true,
                  strong: true,
                  validate: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (String _) => _submit(),
                ),
                if (_missing != null) _DigitsHint(count: _missing!),
                if (notice != null)
                  AuthNotice(view: notice, onAction: _onNotice),
                LockMessage(
                  lockedSeconds: locked ? state.lockedSeconds : 0,
                  lockOver: sameNumber && state.lockOver,
                  speaks: ModalRoute.isCurrentOf(context) ?? true,
                ),
                const SizedBox(height: 20),
                KeyedSubtree(
                  key: _buttonKey,
                  child: SubmitButton(
                    buttonKey: const ValueKey<String>('continue-button'),
                    face: face,
                    label: face == SubmitFace.busy
                        ? l10n.sendingCode
                        : l10n.getCodeButton,
                    offHint: missing > 0 ? l10n.phoneDigitsLeft(missing) : null,
                    onPressed: _submit,
                    onOffTap: _sayMissing,
                  ),
                ),
                // The line keeps 13 above its text for its link targets, so
                // its text stands 14 below the button.
                const SizedBox(height: 1),
                const ConsentLine(),
              ],
            );
          },
        ),
      ),
    );
  }

  /// A failure belongs to this page only when the request itself failed: the
  /// code page shows the failures of its own calls.
  AuthNoticeView? _noticeOf(AppLocalizations l10n, CodeLoginState state) {
    final failure = state.failure;
    if (failure == null || state.failedAction != CodeLoginAction.request) {
      return null;
    }
    return authNoticeOf(
      l10n,
      failure,
      phone: state.phone ?? '',
      place: AuthNoticePlace.phone,
    );
  }
}

/// «Введите ещё N цифр»: 13 w600 under the field, coming in by opacity and a
/// 6 px rise in 220 ms, opacity alone in 200 ms with reduced motion.
class _DigitsHint extends StatefulWidget {
  const _DigitsHint({required this.count});

  final int count;

  @override
  State<_DigitsHint> createState() => _DigitsHintState();
}

class _DigitsHintState extends State<_DigitsHint>
    with SingleTickerProviderStateMixin {
  static const Curve _curve = Cubic(0.2, 0.8, 0.2, 1);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    animationBehavior: AnimationBehavior.preserve,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _controller.duration = Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 200 : 220,
      );
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return Padding(
      key: const ValueKey<String>('phone-digits-hint'),
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double t = reduced
              ? _controller.value
              : _curve.transform(_controller.value);
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, reduced ? 0 : -6 * (1 - t)),
              child: child,
            ),
          );
        },
        child: Text(
          AppLocalizations.of(context).phoneDigitsLeft(widget.count),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: KitColors.ink2,
          ),
        ),
      ),
    );
  }
}
