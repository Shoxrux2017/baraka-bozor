import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/accessibility/announce.dart';
import '../core/localization/generated/app_localizations.dart';
import '../core/session/session_state.dart';
import '../core/theme/kit_colors.dart';
import '../core/widgets/brand_wordmark.dart';
import '../core/widgets/wordmark_landing.dart';
import '../features/auth/presentation/unreachable_screen.dart';
import 'providers.dart';

/// The launch curtain and the handoff to the first page (`DL-136` (11), (12),
/// (17)).
///
/// While the stored sessions are confirmed the curtain stands over the router:
/// white, the wordmark fading in and, after 1.5 s, «Подключаемся…». When the
/// first answer is in and the router has built the first page, the curtain
/// leaves: the wordmark glides into the sign-in's own wordmark when that is
/// the first page, and every other first page — and every leave with reduced
/// motion — comes through a 250 ms fade. Leaving «Нет связи» for the app fades
/// that screen's last picture away the same way. A curtain and not a route
/// transition: the entry pages are `NoTransitionPage`s, go_router completes
/// the old route rather than popping it, so a route fade starts from black and
/// a `Hero` does not fly (`DL-135` (7)).
class SessionHandoff extends ConsumerStatefulWidget {
  const SessionHandoff({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SessionHandoff> createState() => _SessionHandoffState();
}

enum _Phase { launching, leaving, gone }

class _SessionHandoffState extends ConsumerState<SessionHandoff>
    with SingleTickerProviderStateMixin {
  static const Duration _glideTime = Duration(milliseconds: 540);
  static const Duration _fadeTime = Duration(milliseconds: 250);
  static const Duration _hintAfter = Duration(milliseconds: 1500);

  /// The ghost's flight is the first 450 of the 540 ms.
  static const Interval _flight = Interval(0, 450 / 540);
  static const Cubic _flightCurve = Cubic(0.2, 0.8, 0.2, 1);

  /// The white and the hint fade out from 120 to 380 ms.
  static const Interval _whiteFade = Interval(
    120 / 540,
    380 / 540,
    curve: Curves.easeOut,
  );

  final WordmarkLandingRegistry _registry = WordmarkLandingRegistry();
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _launchWordmarkKey = GlobalKey();
  late final AnimationController _leave = AnimationController(
    vsync: this,
    // The platform's reduced motion must not cut this clock: a leave with
    // reduced motion is still a 250 ms fade (`DL-134` Ruling (14)(a)).
    animationBehavior: AnimationBehavior.preserve,
  );

  _Phase _phase = _Phase.launching;
  bool _hint = false;
  bool _deciding = false;
  Timer? _hintTimer;

  /// The last «Нет связи» state seen, to draw when it is left.
  SessionUnreachable? _unreachable;

  /// What the curtain draws while leaving «Нет связи».
  SessionUnreachable? _picture;
  bool _glide = false;
  Rect? _from;
  Rect? _to;

  @override
  void initState() {
    super.initState();
    final AsyncValue<SessionState> session = ref.read(
      sessionControllerProvider,
    );
    if (session.hasValue || session.hasError) {
      _phase = _Phase.gone;
    } else {
      _hintTimer = Timer(_hintAfter, _showHint);
    }
    _leave.addStatusListener(_onLeaveStatus);
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _registry.hidden.value = false;
    _leave.dispose();
    _registry.hidden.dispose();
    super.dispose();
  }

  void _showHint() {
    _hintTimer = null;
    if (!mounted || _phase != _Phase.launching) {
      return;
    }
    setState(() => _hint = true);
    announce(context, AppLocalizations.of(context).bootConnecting);
  }

  void _onSession(
    AsyncValue<SessionState>? previous,
    AsyncValue<SessionState> next,
  ) {
    final SessionState? value = next.value;
    if (value is SessionUnreachable) {
      _unreachable = value;
    }
    if (_phase == _Phase.launching) {
      if ((next.hasValue || next.hasError) && !_deciding) {
        _deciding = true;
        _hintTimer?.cancel();
        _hintTimer = null;
        // The router builds the first page in the next frame; the curtain
        // decides how to leave once that frame is on screen.
        WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
        WidgetsBinding.instance.scheduleFrame();
      }
    } else if (_phase == _Phase.gone &&
        _unreachable != null &&
        (value is SignedIn || value is SignedOut)) {
      _leaveWithPicture(_unreachable!);
    }
    if (value is SignedIn || value is SignedOut) {
      _unreachable = null;
    }
  }

  void _decide() {
    if (!mounted) {
      return;
    }
    final Rect? from = _rectOf(_launchWordmarkKey);
    final GlobalKey? landing = _registry.current;
    final Rect? to = landing == null ? null : _rectOf(landing);
    final Size? screen = _stackBox()?.size;
    final bool onScreen =
        to != null &&
        screen != null &&
        (Offset.zero & screen).overlaps(to) &&
        to.width > 0;
    final bool glide =
        !MediaQuery.disableAnimationsOf(context) &&
        from != null &&
        from.width > 0 &&
        onScreen;
    setState(() {
      _phase = _Phase.leaving;
      _glide = glide;
      _from = glide ? from : null;
      _to = glide ? to : null;
    });
    if (glide) {
      _registry.hidden.value = true;
    }
    _leave
      ..duration = glide ? _glideTime : _fadeTime
      ..forward(from: 0);
  }

  void _leaveWithPicture(SessionUnreachable state) {
    setState(() {
      _phase = _Phase.leaving;
      _picture = state;
      _glide = false;
      _from = null;
      _to = null;
    });
    _leave
      ..duration = _fadeTime
      ..forward(from: 0);
  }

  void _onLeaveStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    _registry.hidden.value = false;
    if (mounted) {
      setState(() {
        _phase = _Phase.gone;
        _picture = null;
        _glide = false;
        _from = null;
        _to = null;
      });
    }
  }

  RenderBox? _stackBox() {
    final RenderObject? box = _stackKey.currentContext?.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize ? box : null;
  }

  /// Where [key]'s widget is, in the handoff's own coordinates; null when it
  /// is not laid out.
  Rect? _rectOf(GlobalKey key) {
    final RenderBox? stack = _stackBox();
    final RenderObject? box = key.currentContext?.findRenderObject();
    if (stack == null || box is! RenderBox || !box.attached || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero, ancestor: stack) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<SessionState>>(sessionControllerProvider, _onSession);
    final bool leaving = _phase == _Phase.leaving;
    final Rect? from = _from;
    final Rect? to = _to;
    return WordmarkLandingScope(
      registry: _registry,
      child: Stack(
        key: _stackKey,
        fit: StackFit.expand,
        children: <Widget>[
          widget.child,
          if (_phase != _Phase.gone)
            IgnorePointer(
              ignoring: leaving,
              child: ExcludeSemantics(
                excluding: leaving,
                child: FadeTransition(
                  key: const ValueKey<String>('launch-curtain'),
                  opacity: leaving
                      ? Tween<double>(begin: 1, end: 0)
                            .chain(
                              CurveTween(
                                curve: _glide ? _whiteFade : Curves.easeOut,
                              ),
                            )
                            .animate(_leave)
                      : const AlwaysStoppedAnimation<double>(1),
                  child: _picture != null
                      ? UnreachableView(state: _picture!)
                      : _Launch(
                          wordmarkKey: _launchWordmarkKey,
                          hint: _hint,
                          wordmarkHidden: _glide,
                        ),
                ),
              ),
            ),
          if (leaving && from != null && to != null)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: _leave,
                    builder: (BuildContext context, Widget? ghost) {
                      final double t = _flightCurve.transform(
                        _flight.transform(_leave.value),
                      );
                      final Offset at = Offset.lerp(
                        from.topLeft,
                        to.topLeft,
                        t,
                      )!;
                      return Stack(
                        children: <Widget>[
                          Positioned(
                            left: at.dx,
                            top: at.dy,
                            child: Transform.scale(
                              alignment: Alignment.topLeft,
                              scale: lerpDouble(1, to.width / from.width, t)!,
                              child: ghost,
                            ),
                          ),
                        ],
                      );
                    },
                    child: const BrandWordmark(
                      key: ValueKey<String>('handoff-ghost'),
                      size: _Launch.wordmarkSize,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The launch picture: white, the wordmark in the middle and, once it is
/// time, the hint under it.
class _Launch extends StatelessWidget {
  const _Launch({
    required this.wordmarkKey,
    required this.hint,
    required this.wordmarkHidden,
  });

  static const double wordmarkSize = 34;

  final GlobalKey wordmarkKey;
  final bool hint;

  /// The wordmark is the ghost's while it glides.
  final bool wordmarkHidden;

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return Material(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Stack(
            children: <Widget>[
              Center(
                child: Opacity(
                  opacity: wordmarkHidden ? 0 : 1,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: reduced ? 1 : 0, end: 1),
                    duration: reduced
                        ? Duration.zero
                        : const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    builder:
                        (BuildContext context, double opacity, Widget? child) =>
                            FadeTransition(
                              key: const ValueKey<String>('launch-wordmark'),
                              opacity: AlwaysStoppedAnimation<double>(opacity),
                              alwaysIncludeSemantics: true,
                              child: child,
                            ),
                    child: BrandWordmark(key: wordmarkKey, size: wordmarkSize),
                  ),
                ),
              ),
              if (hint)
                Positioned(
                  left: 24,
                  right: 24,
                  top: constraints.maxHeight / 2 + 38,
                  child: const _Hint(),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A 18 px spinner and «Подключаемся…» in muted grey, fading in over 300 ms.
class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: reduced ? 1 : 0, end: 1),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (BuildContext context, double opacity, Widget? child) =>
          FadeTransition(
            key: const ValueKey<String>('launch-hint'),
            opacity: AlwaysStoppedAnimation<double>(opacity),
            child: child,
          ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox.square(
            dimension: 18,
            child: ExcludeSemantics(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: KitColors.muted,
                backgroundColor: KitColors.muted.withValues(alpha: 0.25),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              AppLocalizations.of(context).bootConnecting,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: KitColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
