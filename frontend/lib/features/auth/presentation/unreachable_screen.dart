import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/session/session_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/submit_button.dart';
import 'auth_scaffold.dart';

/// A stored session the server could not confirm: the tokens are kept and
/// the person tries again (`docs/DECISIONS.md` DL-13, point 4). The screen
/// also checks by itself (`DL-136` (14), (15)): quietly 5, 10, 20 and 30 s
/// apart and then every 30 s, the series starting over after each pressed
/// check, and at once when the app comes back to the front or the phone's
/// network returns. The session controller runs one check at a time, so these
/// only join one that is already out.
class UnreachableScreen extends ConsumerStatefulWidget {
  const UnreachableScreen({super.key});

  @override
  ConsumerState<UnreachableScreen> createState() => _UnreachableScreenState();
}

class _UnreachableScreenState extends ConsumerState<UnreachableScreen>
    with WidgetsBindingObserver {
  /// How long after the last check the next quiet one starts, by place in the
  /// series; the last one repeats.
  static const List<Duration> _series = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
    Duration(seconds: 30),
  ];

  Timer? _timer;
  StreamSubscription<void>? _regained;
  int _quietChecks = 0;
  SessionUnreachable _last = const SessionUnreachable();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _regained = ref
        .read(connectivitySignalProvider)
        .regained
        .listen((_) => _checkQuietly());
    _arm();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_regained?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkQuietly();
    }
  }

  /// Starts the wait for the next quiet check of the series.
  void _arm() {
    _timer?.cancel();
    final int place = _quietChecks < _series.length
        ? _quietChecks
        : _series.length - 1;
    _timer = Timer(_series[place], () {
      _timer = null;
      _quietChecks++;
      _checkQuietly();
    });
  }

  /// One quiet check, or the one already out; when it ends and nothing else
  /// has armed the series, the next wait begins.
  void _checkQuietly() {
    final Future<void> check = ref
        .read(sessionControllerProvider.notifier)
        .retry(quiet: true);
    unawaited(
      check.whenComplete(() {
        if (mounted && _timer == null) {
          _arm();
        }
      }),
    );
  }

  void _press() {
    announce(context, AppLocalizations.of(context).unreachableCheckingSpoken);
    unawaited(ref.read(sessionControllerProvider.notifier).retry());
  }

  void _onSession(
    AsyncValue<SessionState>? previous,
    AsyncValue<SessionState> next,
  ) {
    final SessionState? before = previous?.value;
    final SessionState? now = next.value;
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (before is! SessionUnreachable) {
      return;
    }
    if (now is SignedIn || now is SignedOut) {
      announce(context, l10n.unreachableOpening);
    } else if (now is SessionUnreachable && before.retrying && !now.retrying) {
      // A pressed check ended without a connection: the series starts over.
      _quietChecks = 0;
      _arm();
      unawaited(HapticFeedback.mediumImpact());
      announce(
        context,
        now.cause == UnreachableCause.offline
            ? l10n.unreachableStillOffline
            : l10n.unreachableStillDown,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<SessionState>>(sessionControllerProvider, _onSession);
    final SessionState? session = ref.watch(sessionControllerProvider).value;
    if (session is SessionUnreachable) {
      _last = session;
    }
    return UnreachableView(state: _last, onRetry: _press);
  }
}

/// The whole picture of «Нет связи» from the state alone (`DL-136`): a grey
/// icon, words that tell a dead network from a broken server, the button and,
/// once a pressed check has failed, when it was. A null [onRetry] draws it
/// the same, but nothing answers a touch.
class UnreachableView extends StatelessWidget {
  const UnreachableView({required this.state, this.onRetry, super.key});

  final SessionUnreachable state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool offline = state.cause == UnreachableCause.offline;
    final DateTime? checkedAt = state.checkedAt;
    final String result = offline
        ? l10n.unreachableStillOffline
        : l10n.unreachableStillDown;
    final String? time = checkedAt == null
        ? null
        : TashkentTime.time(checkedAt);

    return AuthStatusScaffold(
      icon: offline ? Icons.wifi_off : Icons.cloud_off,
      titleKey: const ValueKey<String>('unreachable-title'),
      title: offline
          ? l10n.unreachableOfflineTitle
          : l10n.unreachableServerTitle,
      body: offline ? l10n.unreachableOfflineBody : l10n.unreachableServerBody,
      button: IgnorePointer(
        ignoring: onRetry == null,
        child: _RetryButton(
          retrying: state.retrying,
          onPressed: onRetry ?? () {},
        ),
      ),
      footnote: time == null
          ? null
          : _CheckedLine(
              text: l10n.unreachableCheckedAt(result, time),
              spoken: l10n.unreachableCheckedAtSpoken(result, time),
            ),
    );
  }
}

/// The green button: «Повторить», or «Проверяем…» with a spinner while a
/// pressed check runs. A reader hears only «Проверяем связь…» then, not a
/// disabled button.
class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.retrying, required this.onPressed});

  final bool retrying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Widget button = SubmitButton(
      buttonKey: const ValueKey<String>('retry-button'),
      face: retrying ? SubmitFace.busy : SubmitFace.ready,
      label: retrying ? l10n.unreachableChecking : l10n.retryButton,
      onPressed: onPressed,
    );
    if (!retrying) {
      return button;
    }
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: l10n.unreachableCheckingSpoken,
      child: button,
    );
  }
}

/// «Связи пока нет · проверено в 9:41», fading in over 200 ms.
class _CheckedLine extends StatelessWidget {
  const _CheckedLine({required this.text, required this.spoken});

  final String text;
  final String spoken;

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: reduced ? 1 : 0, end: 1),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      builder: (BuildContext context, double opacity, Widget? child) =>
          Opacity(opacity: opacity, alwaysIncludeSemantics: true, child: child),
      child: Semantics(
        label: spoken,
        excludeSemantics: true,
        child: Text(
          text,
          key: const ValueKey<String>('unreachable-checked'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: KitColors.muted,
          ),
        ),
      ),
    );
  }
}
