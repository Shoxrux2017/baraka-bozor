import 'package:flutter/material.dart';

/// Fades its sliver in over 200 ms `easeOut` when [animate] is set (the data
/// that replaces skeletons); with reduced motion, or without [animate], it is
/// there at once.
class FadeInSliver extends StatefulWidget {
  const FadeInSliver({required this.animate, required this.sliver, super.key});

  final bool animate;
  final Widget sliver;

  @override
  State<FadeInSliver> createState() => _FadeInSliverState();
}

class _FadeInSliverState extends State<FadeInSliver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (widget.animate && !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverFadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      sliver: widget.sliver,
    );
  }
}
