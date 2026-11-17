import 'package:flutter/material.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/failure_text.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/kit_colors.dart';

/// The sign-in page a refusal is shown on (`DL-139`).
enum AuthNoticePlace { phone, code, name }

enum AuthNoticeTone { danger, warning }

/// The way out a notice offers.
enum AuthNoticeAction { retry, otherNumber, changeNumber, newCode }

/// What a sign-in refusal looks like: tone, icon, plain words and its way out.
final class AuthNoticeView {
  const AuthNoticeView({
    required this.tone,
    required this.icon,
    required this.text,
    this.action,
  });

  final AuthNoticeTone tone;
  final IconData icon;
  final String text;
  final AuthNoticeAction? action;
}

/// A wait in words: whole minutes rounded up from a minute on, else seconds.
String waitWords(AppLocalizations l10n, int seconds) {
  if (seconds >= 60) {
    return l10n.waitMinutes((seconds + 59) ~/ 60);
  }
  return l10n.waitSeconds(seconds);
}

/// Maps a sign-in [failure] to its notice (`DL-139` point 9). [phone] is the
/// E.164 number the code was asked for.
AuthNoticeView authNoticeOf(
  AppLocalizations l10n,
  ApiFailure failure, {
  required String phone,
  required AuthNoticePlace place,
}) {
  final String serverText = failureText(l10n, failure) ?? l10n.errorUnknown;

  AuthNoticeView warning(
    IconData icon,
    String text,
    AuthNoticeAction? action,
  ) => AuthNoticeView(
    tone: AuthNoticeTone.warning,
    icon: icon,
    text: text,
    action: action,
  );

  AuthNoticeView danger(IconData icon, String text, AuthNoticeAction? action) =>
      AuthNoticeView(
        tone: AuthNoticeTone.danger,
        icon: icon,
        text: text,
        action: action,
      );

  /// "Another number" on the phone page, "change the number" on the code
  /// page, nothing on the name page.
  AuthNoticeAction? numberAction() => switch (place) {
    AuthNoticePlace.phone => AuthNoticeAction.otherNumber,
    AuthNoticePlace.code => AuthNoticeAction.changeNumber,
    AuthNoticePlace.name => null,
  };

  if (failure is NetworkFailure) {
    return danger(Icons.wifi_off, l10n.authNoInternet, AuthNoticeAction.retry);
  }
  if (failure is! ApiRefusal) {
    return danger(Icons.error_outline, serverText, null);
  }

  switch (failure.code) {
    case 'code_delivery_unavailable':
      return warning(
        Icons.person_search,
        l10n.authNotInTelegram(formatPhone(phone)),
        numberAction(),
      );
    case 'rate_limited':
      final int? wait = failure.retryAfterSeconds;
      if (wait == null) {
        return warning(Icons.schedule, serverText, null);
      }
      final Object? limit = failure.error.details['limit'];
      final Object? maxSends = failure.error.details['max_sends'];
      if (limit == 'phone_hourly' && maxSends is num) {
        return warning(
          Icons.schedule,
          l10n.authHourLimit(maxSends.toInt(), waitWords(l10n, wait)),
          numberAction(),
        );
      }
      if (limit == 'address') {
        return warning(
          Icons.schedule,
          l10n.authAddressLimit(waitWords(l10n, wait)),
          null,
        );
      }
      return warning(
        Icons.schedule,
        l10n.authTooMany(waitWords(l10n, wait)),
        null,
      );
    case 'code_expired' || 'code_attempts_exhausted':
      return warning(
        Icons.timer_off,
        serverText,
        place == AuthNoticePlace.code ? AuthNoticeAction.newCode : null,
      );
    case 'provider_unavailable' || 'service_unavailable':
      return danger(Icons.cloud_off, serverText, AuthNoticeAction.retry);
  }
  if (failure.status >= 500) {
    return danger(Icons.cloud_off, serverText, AuthNoticeAction.retry);
  }
  return danger(Icons.error_outline, serverText, null);
}

/// A sign-in refusal as a box with an icon, plain words and its way out
/// (`DL-139`). It announces its text when it appears and when it changes.
class AuthNotice extends StatefulWidget {
  const AuthNotice({required this.view, required this.onAction, super.key});

  final AuthNoticeView view;
  final ValueChanged<AuthNoticeAction> onAction;

  @override
  State<AuthNotice> createState() => _AuthNoticeState();
}

class _AuthNoticeState extends State<AuthNotice>
    with SingleTickerProviderStateMixin {
  static const Curve _curve = Cubic(0.2, 0.8, 0.2, 1);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    animationBehavior: AnimationBehavior.preserve,
  );
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        announce(context, widget.view.text);
      }
    });
  }

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
  void didUpdateWidget(AuthNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view.text != widget.view.text) {
      announce(context, widget.view.text);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _label(AppLocalizations l10n, AuthNoticeAction action) {
    return switch (action) {
      AuthNoticeAction.retry => l10n.retryButton,
      AuthNoticeAction.otherNumber => l10n.authOtherNumber,
      AuthNoticeAction.changeNumber => l10n.changePhone,
      AuthNoticeAction.newCode => l10n.codeNewCode,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AuthNoticeView view = widget.view;
    final bool isDanger = view.tone == AuthNoticeTone.danger;
    final Color wash = isDanger ? KitColors.dangerWash : KitColors.warningWash;
    final Color textColor = isDanger ? KitColors.danger : KitColors.ink2;
    final Color iconColor = isDanger ? KitColors.danger : KitColors.warningDark;
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final AuthNoticeAction? action = view.action;

    final Widget box = DecoratedBox(
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 12, 12, action == null ? 12 : 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              container: true,
              label: view.text,
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(view.icon, size: 20, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      view.text,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (action != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('auth-notice-action'),
                  onPressed: () => widget.onAction(action),
                  style: TextButton.styleFrom(
                    foregroundColor: KitColors.primaryDark,
                    minimumSize: const Size(0, 44),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(_label(l10n, action)),
                ),
              ),
          ],
        ),
      ),
    );

    return Padding(
      key: const Key('auth-notice'),
      padding: const EdgeInsets.only(top: 12),
      child: AnimatedBuilder(
        animation: _controller,
        child: box,
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
      ),
    );
  }
}
