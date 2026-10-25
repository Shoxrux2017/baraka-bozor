import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/visible_location.dart';
import '../domain/push.dart';
import '../domain/push_event.dart';
import 'push_opener.dart';
import 'push_ports.dart';

/// Shows a push that arrives while the app is open, since the system draws
/// notifications only for an app in the background (`DL-115` (6)), and names
/// the channel those notifications belong to in the app's language.
///
/// A push about the order the person is looking at needs no banner: the
/// screen is already live. Every other push is shown, whatever mode the phone
/// is in; the banner's tap, not its appearance, is where the mode matters.
class PushPresenter {
  PushPresenter(this._ref) {
    final PushInbox inbox = _ref.read(pushInboxProvider);
    final StreamSubscription<IncomingPush> foreground = inbox.foreground.listen(
      _show,
    );
    _ref.onDispose(foreground.cancel);

    final PushOpener opener = _ref.read(pushOpenerProvider);
    final BannerDisplay display = _ref.read(bannerDisplayProvider);
    _ref.onDispose(inbox.opened.listen(opener.open).cancel);
    _ref.onDispose(display.taps.listen(opener.open).cancel);
    _guard(_openLaunch(inbox, display, opener), 'while reading the launch tap');

    // Until the stored preference is read the device language applies, the
    // same value for anyone who never chose one.
    _prepare(_language(_ref.read(languageControllerProvider).value));
    _ref.listen<AsyncValue<AppLanguage>>(
      languageControllerProvider,
      (AsyncValue<AppLanguage>? previous, AsyncValue<AppLanguage> next) =>
          _prepare(_language(next.value)),
    );
  }

  final Ref _ref;
  AppLanguage? _prepared;

  AppLanguage _language(AppLanguage? chosen) =>
      chosen ?? AppLanguage.forDevice(_ref.read(deviceLocaleProvider));

  void _prepare(AppLanguage language) {
    if (language == _prepared) {
      return;
    }
    _prepared = language;
    final AppLocalizations strings = lookupAppLocalizations(language.locale);
    _guard(
      _ref
          .read(bannerDisplayProvider)
          .prepare(
            BannerChannel(
              name: strings.pushChannelName,
              description: strings.pushChannelDescription,
            ),
          ),
      'while preparing the push channel',
    );
  }

  /// The tap that started the app, from the system's notification or from a
  /// banner the app drew; the first one found wins.
  Future<void> _openLaunch(
    PushInbox inbox,
    BannerDisplay display,
    PushOpener opener,
  ) async {
    final PushTarget? target =
        await inbox.launchTarget() ?? await display.launchTarget();
    if (target != null) {
      opener.open(target);
    }
  }

  void _show(IncomingPush push) {
    final PushTarget? target = push.target;
    if (target != null &&
        target.path == _ref.read(routerProvider).visiblePath) {
      return;
    }
    _guard(_ref.read(bannerDisplayProvider).show(push), 'while showing a push');
  }

  /// A banner that cannot be drawn is reported, never thrown into the
  /// stream that delivered the push.
  void _guard(Future<void> work, String what) {
    unawaited(
      work.catchError((Object error, StackTrace stackTrace) {
        reportUnexpectedError(error, stackTrace, what);
      }),
    );
  }
}

/// The one presenter of the process, kept alive by the app root.
final Provider<PushPresenter> pushPresenterProvider = Provider<PushPresenter>(
  PushPresenter.new,
);
