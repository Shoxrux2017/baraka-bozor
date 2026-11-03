import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderStack;
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import 'app_page.dart';

/// How a flying piece changes size on its way (`DL-128`). A [scale] piece is
/// laid out at the size of its place and scaled from where it was, origin at
/// the top left; a [stretch] piece is laid out at the size it has at that
/// moment.
enum FlightFit { scale, stretch }

/// A piece of the screen the person tapped that flies to its place on the page
/// that opens (`DL-128`). [from] is where the piece was, in global coordinates;
/// [builder] draws a copy of it; the place it lands on is the
/// [FlightTarget] with the same [id].
final class FlightItem {
  const FlightItem({
    required this.id,
    required this.from,
    required this.builder,
    this.fit = FlightFit.scale,
  });

  final String id;
  final Rect from;
  final WidgetBuilder builder;
  final FlightFit fit;
}

/// What a flight page opens with. [screen] is the size [FlightItem.from] was
/// measured on: on another size nothing flies. [holding] is true while the
/// pieces are away from their sources, so a source can hide itself; it must
/// outlive the page.
final class FlightOpening {
  const FlightOpening({
    required this.items,
    required this.screen,
    this.holding,
  });

  final List<FlightItem> items;
  final Size screen;
  final ValueNotifier<bool>? holding;
}

const Curve _flightCurve = Cubic(0.2, 0.8, 0.2, 1);

/// The page of a route that opens with a flight (`DL-128`): the page fades in
/// over the still page below while the pieces of [opening] fly from where they
/// were to their [FlightTarget]s, and back. Without an [opening] it is the
/// ordinary [appPage]. The platform keeps its back gestures.
Page<void> flightPage(
  GoRouterState state,
  Widget child, {
  required FlightOpening? opening,
  Duration flight = const Duration(milliseconds: 400),
  Duration flightBack = const Duration(milliseconds: 400),
}) {
  if (opening == null) {
    return appPage(state, child);
  }
  final ValueKey<String> key = state.pageKey;
  return _FlightPage(
    key: key,
    name: state.name ?? state.path,
    arguments: <String, String>{
      ...state.pathParameters,
      ...state.uri.queryParameters,
    },
    restorationId: key.value,
    opening: opening,
    flight: flight,
    flightBack: flightBack,
    child: child,
  );
}

/// A place a piece of a flight lands on (`DL-128`). It is drawn at opacity 0
/// while its piece flies; outside a flight page it is its child.
class FlightTarget extends StatefulWidget {
  const FlightTarget({required this.id, required this.child, super.key});

  final String id;
  final Widget child;

  @override
  State<FlightTarget> createState() => _FlightTargetState();
}

class _FlightTargetState extends State<FlightTarget> {
  _FlightSceneState? _scene;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final _FlightScope? scope = context
        .dependOnInheritedWidgetOfExactType<_FlightScope>();
    _scene?._targets.remove(widget.id);
    _scene = scope?.scene;
    _scene?._targets[widget.id] = this;
  }

  @override
  void didUpdateWidget(FlightTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _scene?._targets.remove(oldWidget.id);
      _scene?._targets[widget.id] = this;
    }
  }

  @override
  void dispose() {
    if (_scene?._targets[widget.id] == this) {
      _scene?._targets.remove(widget.id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _FlightScope? scope = context
        .dependOnInheritedWidgetOfExactType<_FlightScope>();
    final bool hidden =
        scope != null && scope.hiding && scope.ids.contains(widget.id);
    return Opacity(opacity: hidden ? 0 : 1, child: widget.child);
  }

  /// The place's rectangle in the coordinates of [scene], or null while it
  /// has none.
  Rect? _rectIn(RenderBox scene) {
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) {
      return null;
    }
    return MatrixUtils.transformRect(
      box.getTransformTo(scene),
      Offset.zero & box.size,
    );
  }
}

class _FlightScope extends InheritedWidget {
  const _FlightScope({
    required this.scene,
    required this.hiding,
    required this.ids,
    required super.child,
  });

  final _FlightSceneState scene;
  final bool hiding;
  final Set<String> ids;

  @override
  bool updateShouldNotify(_FlightScope oldWidget) => hiding != oldWidget.hiding;
}

class _FlightPage extends Page<void> {
  const _FlightPage({
    required this.child,
    required this.opening,
    required this.flight,
    required this.flightBack,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;
  final FlightOpening opening;
  final Duration flight;
  final Duration flightBack;

  @override
  Route<void> createRoute(BuildContext context) =>
      _FlightRoute(this, reduced: MediaQuery.disableAnimationsOf(context));
}

class _FlightRoute extends PageRoute<void> {
  _FlightRoute(_FlightPage page, {required this.reduced})
    : super(settings: page);

  final bool reduced;

  _FlightPage get _page => settings as _FlightPage;

  @override
  Duration get transitionDuration => reduced
      ? const Duration(milliseconds: 200)
      : _page.flight + const Duration(milliseconds: 20);

  @override
  Duration get reverseTransitionDuration {
    if (reduced) {
      return const Duration(milliseconds: 200);
    }
    final Duration back = _page.flightBack;
    const Duration least = Duration(milliseconds: 220);
    return (back > least ? back : least) + const Duration(milliseconds: 20);
  }

  @override
  bool get maintainState => true;

  /// With reduced motion the framework would cut a controller's time to a
  /// twentieth; this page has its own reduced timing, so it keeps its times.
  @override
  AnimationController createAnimationController() => AnimationController(
    duration: transitionDuration,
    reverseDuration: reverseTransitionDuration,
    debugLabel: debugLabel,
    animationBehavior: AnimationBehavior.preserve,
    vsync: navigator!,
  );

  /// A committed back gesture pops the route and lets the scene turn back from
  /// where the pieces are. The framework would jump the controller to its end
  /// first and replay the way back linearly; the gesture ends before the pop,
  /// so the scene sees an ordinary reverse.
  @override
  void handleCommitBackGesture() {
    if (!isCurrent) {
      super.handleCommitBackGesture();
      return;
    }
    navigator?.didStopUserGesture();
    navigator?.pop();
  }

  /// Keeps the scene alive when a platform builder wraps it differently (the
  /// Android predictive back does, from the start of a gesture to its end).
  final GlobalKey<State<_FlightScene>> _sceneKey =
      GlobalKey<State<_FlightScene>>();

  /// The route's own run, 0 to 1. [animation] is swapped for a finished one
  /// while the page is first built off stage, so the scene reads this instead.
  Animation<double> get run => controller!.view;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: _page.child,
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Widget scene = _FlightScene(
      key: _sceneKey,
      route: this,
      opening: _page.opening,
      flight: _page.flight,
      flightBack: _page.flightBack,
      child: child,
    );
    // The theme's builder gets a finished primary animation, so the page does
    // not slide, but its back gesture still drives this route's controller.
    return Theme.of(context).pageTransitionsTheme.buildTransitions<void>(
      this,
      context,
      kAlwaysCompleteAnimation,
      secondaryAnimation,
      scene,
    );
  }
}

class _FlightScene extends StatefulWidget {
  const _FlightScene({
    required this.route,
    required this.opening,
    required this.flight,
    required this.flightBack,
    required this.child,
    super.key,
  });

  final _FlightRoute route;
  final FlightOpening opening;
  final Duration flight;
  final Duration flightBack;
  final Widget child;

  @override
  State<_FlightScene> createState() => _FlightSceneState();
}

class _FlightSceneState extends State<_FlightScene>
    with TickerProviderStateMixin {
  final Map<String, _FlightTargetState> _targets =
      <String, _FlightTargetState>{};

  /// How far the pieces have flown, 0 at their sources and 1 at their places.
  late final AnimationController _fly = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );

  /// The page's opacity.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );

  final GlobalKey _stack = GlobalKey();

  /// Where the scene sits on the screen, measured after each frame of a flight
  /// (the pieces' sources are in screen coordinates).
  Offset _origin = Offset.zero;

  late Animation<double> _routeAnimation;
  bool _flying = true;
  bool _flies = true;

  bool get _reduced => widget.route.reduced;

  bool get _gesture => widget.route.navigator?.userGestureInProgress ?? false;

  @override
  void initState() {
    super.initState();
    _routeAnimation = widget.route.run;
    _routeAnimation.addListener(_follow);
    _routeAnimation.addStatusListener(_statusChanged);
    final AnimationStatus status = _routeAnimation.status;
    _flying = status != AnimationStatus.completed;
    if (status == AnimationStatus.completed) {
      _snap();
    } else if (status == AnimationStatus.forward) {
      _go(1);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _flies = !_reduced && MediaQuery.sizeOf(context) == widget.opening.screen;
    _syncHolding();
  }

  @override
  void dispose() {
    _routeAnimation.removeListener(_follow);
    _routeAnimation.removeStatusListener(_statusChanged);
    // A route that leaves without finishing its way back still frees its source.
    final ValueNotifier<bool>? holding = widget.opening.holding;
    if (holding != null &&
        holding.value &&
        _routeAnimation.status != AnimationStatus.dismissed) {
      // The tree is locked while a State is disposed; the notifier outlives
      // this page, so it is written once the frame is done.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        holding.value = false;
      });
    }
    _fly.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _snap() {
    _fly.value = 1;
    _fade.value = 1;
  }

  /// While a finger drags the page back the flight follows it linearly.
  void _follow() {
    if (_gesture) {
      _fly.value = _routeAnimation.value;
      _fade.value = _routeAnimation.value;
    }
  }

  void _statusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _snap();
    } else if (!_gesture) {
      if (status == AnimationStatus.forward) {
        _go(1);
      } else if (status == AnimationStatus.reverse) {
        _go(0);
      }
    }
    final bool flying =
        status == AnimationStatus.forward || status == AnimationStatus.reverse;
    if (flying != _flying) {
      _flying = flying;
      _whenSafe(() => setState(() {}));
      _syncHolding();
    }
  }

  /// Runs the flight and the fade towards [target] from where they are, never
  /// longer than the route has left to run.
  void _go(double target) {
    final bool forward = target == 1;
    final double value = _routeAnimation.value;
    final Duration left = forward
        ? widget.route.transitionDuration * (1 - value)
        : widget.route.reverseTransitionDuration * value;
    _drive(
      _fly,
      target,
      forward ? widget.flight : widget.flightBack,
      _flightCurve,
      left,
    );
    if (_reduced) {
      _drive(
        _fade,
        target,
        const Duration(milliseconds: 200),
        forward ? Curves.easeOut : Curves.easeIn,
        left,
      );
    } else if (forward) {
      _drive(
        _fade,
        target,
        const Duration(milliseconds: 300),
        const Interval(0.2, 1, curve: Curves.easeOut),
        left,
      );
    } else {
      _drive(
        _fade,
        target,
        const Duration(milliseconds: 220),
        Curves.easeIn,
        left,
      );
    }
  }

  void _drive(
    AnimationController controller,
    double target,
    Duration full,
    Curve curve,
    Duration left,
  ) {
    Duration duration = full * (target - controller.value).abs();
    if (duration > left) {
      duration = left;
    }
    controller.animateTo(target, duration: duration, curve: curve);
  }

  void _syncHolding() {
    final ValueNotifier<bool>? holding = widget.opening.holding;
    if (holding == null) {
      return;
    }
    final bool value = _flying && _flies;
    if (holding.value != value) {
      _whenSafe(() => holding.value = value);
    }
  }

  /// A change that dirties other widgets waits for the end of a build.
  void _whenSafe(VoidCallback change) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          change();
        }
      });
    } else if (mounted) {
      change();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool flights = _flying && _flies;
    return _FlightScope(
      scene: this,
      hiding: flights,
      ids: <String>{
        for (final FlightItem item in widget.opening.items) item.id,
      },
      child: Stack(
        key: _stack,
        fit: StackFit.expand,
        children: <Widget>[
          FadeTransition(
            key: const ValueKey<String>('flight-page-fade'),
            opacity: _fade,
            child: widget.child,
          ),
          if (flights)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _fly,
                builder: (BuildContext context, Widget? _) =>
                    LayoutBuilder(builder: _copies),
              ),
            ),
        ],
      ),
    );
  }

  void _measureOrigin() {
    final RenderObject? box = _stack.currentContext?.findRenderObject();
    if (!mounted || box is! RenderBox || !box.attached) {
      return;
    }
    final Offset origin = box.localToGlobal(Offset.zero);
    if (origin != _origin) {
      setState(() => _origin = origin);
    }
  }

  /// The copies, drawn at the moment of the flight from where the targets are
  /// now (read while laying out, after the page below them).
  Widget _copies(BuildContext context, BoxConstraints constraints) {
    final RenderObject? scene = context
        .findAncestorRenderObjectOfType<RenderStack>();
    if (scene is! RenderBox) {
      return const SizedBox.shrink();
    }
    SchedulerBinding.instance.addPostFrameCallback((_) => _measureOrigin());
    final Offset origin = _origin;
    final Rect screen = Offset.zero & constraints.biggest;
    final double progress = _fly.value;
    final List<Widget> copies = <Widget>[];
    for (final FlightItem item in widget.opening.items) {
      final Rect? place = _targets[item.id]?._rectIn(scene);
      if (place == null) {
        continue;
      }
      if (place.isEmpty || !place.overlaps(screen)) {
        continue;
      }
      final Rect from = item.from.shift(-origin);
      final Widget piece = HeroMode(
        enabled: false,
        child: IgnorePointer(
          child: ExcludeSemantics(child: Builder(builder: item.builder)),
        ),
      );
      if (item.fit == FlightFit.stretch) {
        copies.add(
          Positioned.fromRect(
            key: ValueKey<String>('flight-${item.id}'),
            rect: Rect.lerp(from, place, progress)!,
            child: piece,
          ),
        );
      } else {
        final double scale = lerpDouble(from.width / place.width, 1, progress)!;
        final Offset corner = Offset.lerp(
          from.topLeft,
          place.topLeft,
          progress,
        )!;
        copies.add(
          Positioned(
            key: ValueKey<String>('flight-${item.id}'),
            left: corner.dx,
            top: corner.dy,
            width: place.width,
            height: place.height,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: piece,
            ),
          ),
        );
      }
    }
    return Stack(clipBehavior: Clip.none, children: copies);
  }
}
