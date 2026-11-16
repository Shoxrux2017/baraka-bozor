import 'package:flutter/widgets.dart';

/// The sign-in wordmarks the launch wordmark can glide to (`DL-136` (11)):
/// every [WordmarkLanding] that is mounted attaches its key, and the last one
/// attached is where the handoff lands.
final class WordmarkLandingRegistry {
  final List<GlobalKey> _keys = <GlobalKey>[];

  /// True while the handoff's ghost wordmark is on its way, so the landing
  /// draws nothing of its own until the ghost arrives.
  final ValueNotifier<bool> hidden = ValueNotifier<bool>(false);

  void attach(GlobalKey key) {
    _keys
      ..remove(key)
      ..add(key);
  }

  void detach(GlobalKey key) => _keys.remove(key);

  /// The landing mounted last, if any.
  GlobalKey? get current => _keys.isEmpty ? null : _keys.last;
}

/// Gives the landings below it the [registry] of the handoff above them.
class WordmarkLandingScope extends InheritedWidget {
  const WordmarkLandingScope({
    required this.registry,
    required super.child,
    super.key,
  });

  final WordmarkLandingRegistry registry;

  static WordmarkLandingRegistry? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<WordmarkLandingScope>()
      ?.registry;

  @override
  bool updateShouldNotify(WordmarkLandingScope oldWidget) =>
      registry != oldWidget.registry;
}

/// Marks a wordmark as the place the launch wordmark glides to. It keeps its
/// place in the layout and draws nothing while the ghost is on its way; its
/// reader label stays. Without a [WordmarkLandingScope] it is just its child.
class WordmarkLanding extends StatefulWidget {
  const WordmarkLanding({required this.child, super.key});

  final Widget child;

  @override
  State<WordmarkLanding> createState() => _WordmarkLandingState();
}

class _WordmarkLandingState extends State<WordmarkLanding> {
  final GlobalKey _key = GlobalKey();
  WordmarkLandingRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final WordmarkLandingRegistry? registry = WordmarkLandingScope.maybeOf(
      context,
    );
    if (registry != _registry) {
      _registry?.detach(_key);
      _registry = registry?..attach(_key);
    }
  }

  @override
  void dispose() {
    _registry?.detach(_key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WordmarkLandingRegistry? registry = _registry;
    if (registry == null) {
      return widget.child;
    }
    return ValueListenableBuilder<bool>(
      valueListenable: registry.hidden,
      builder: (BuildContext context, bool hidden, Widget? child) => Opacity(
        key: _key,
        opacity: hidden ? 0 : 1,
        alwaysIncludeSemantics: true,
        child: child,
      ),
      child: widget.child,
    );
  }
}
