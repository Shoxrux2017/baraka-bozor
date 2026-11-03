import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/generated/app_localizations.dart';
import '../routing/app_paths.dart';
import '../routing/flight_page.dart';

import '../theme/kit_colors.dart';

/// The kit screens' app bar: a centred title on plain white, without Material
/// 3's tint and without a colour change when the body scrolls under it. With
/// [search] it carries the search icon of a list's header, which opens the
/// search screen (`DL-83`); the [actions] follow it (`DL-118`). A [leading]
/// widget replaces the back arrow. With [fadeTitle] a title whose text changes
/// fades in from 0.25 over 180 ms, at once with reduced motion (`DL-127`). With
/// [titleFlight] the title is the place a flight page's piece lands on
/// (`DL-128`).
AppBar kitAppBar({
  required String title,
  bool automaticallyImplyLeading = true,
  bool search = false,
  bool fadeTitle = false,
  bool titleFlight = false,
  List<Widget>? actions,
  Widget? leading,
}) {
  final Text text = Text(
    title,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: KitColors.ink,
    ),
  );
  final Widget heading = fadeTitle ? _FadingTitle(text) : text;
  return AppBar(
    automaticallyImplyLeading: automaticallyImplyLeading,
    leading: leading,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    centerTitle: true,
    actions: <Widget>[if (search) const _SearchAction(), ...?actions],
    title: titleFlight ? FlightTarget(id: 'title', child: heading) : heading,
  );
}

/// A title that fades in each time its text changes from one already shown.
class _FadingTitle extends StatefulWidget {
  const _FadingTitle(this.title);

  final Text title;

  @override
  State<_FadingTitle> createState() => _FadingTitleState();
}

class _FadingTitleState extends State<_FadingTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.25,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void didUpdateWidget(_FadingTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String? before = oldWidget.title.data;
    if (before != null &&
        before.isNotEmpty &&
        before != widget.title.data &&
        !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      key: const ValueKey<String>('title-fade'),
      opacity: _opacity,
      child: widget.title,
    );
  }
}

class _SearchAction extends StatelessWidget {
  const _SearchAction();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey<String>('open-search'),
      icon: const Icon(Icons.search, size: 26, color: KitColors.ink),
      tooltip: AppLocalizations.of(context).openSearch,
      onPressed: () => context.push<void>(AppPaths.customerSearch),
    );
  }
}
