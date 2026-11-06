import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A one-shot request for the next [EntranceFade] to fade in (`DL-135`). A
/// plain field, not provider state: [take] runs in `initState`, where Riverpod
/// forbids changing state while the tree builds.
class EntranceFadeRequest {
  bool _pending = false;

  /// Whether a fade is waiting for a screen to take it.
  bool get pending => _pending;

  /// Asks the next [EntranceFade] to build to fade in.
  void request() => _pending = true;

  /// Returns whether a fade was requested and clears the request.
  bool take() {
    final bool was = _pending;
    _pending = false;
    return was;
  }
}

/// The request the profile's logout leaves for the sign-in (`DL-135`).
final Provider<EntranceFadeRequest> entranceFadeProvider =
    Provider<EntranceFadeRequest>((Ref ref) => EntranceFadeRequest());

/// [child] as it is, unless a fade was requested before it first built and
/// motion is allowed: then white stands at once and [child] fades in over it
/// in 320 ms (`DL-135`). A route-level fade would start from black, as the
/// page it replaces is already gone.
class EntranceFade extends ConsumerStatefulWidget {
  const EntranceFade({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends ConsumerState<EntranceFade>
    with SingleTickerProviderStateMixin {
  AnimationController? _run;
  Animation<double>? _opacity;

  @override
  void initState() {
    super.initState();
    // Taken once, whatever the motion setting, so a request never waits for a
    // later screen.
    if (ref.read(entranceFadeProvider).take()) {
      _run = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 320),
      );
      _opacity = CurvedAnimation(parent: _run!, curve: Curves.easeOut);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AnimationController? run = _run;
    if (run != null &&
        run.status == AnimationStatus.dismissed &&
        !MediaQuery.disableAnimationsOf(context)) {
      unawaited(run.forward());
    }
  }

  @override
  void dispose() {
    _run?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double>? opacity = _opacity;
    if (opacity == null || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return ColoredBox(
      color: Colors.white,
      child: FadeTransition(opacity: opacity, child: widget.child),
    );
  }
}
