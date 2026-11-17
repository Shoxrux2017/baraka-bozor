import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../layout/text_width.dart';
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
/// (`DL-128`). With [titleOpacity] the title is drawn at that opacity and is
/// always silent to a reader (the page's large title speaks); with
/// [edgeOpacity] a 1 px hairline is the bar's bottom at that opacity, so a
/// page whose text scrolls under the bar can hand its large title over to it
/// (`DL-136`). With [subtitle] a small line stands under the title and both
/// are one heading a reader speaks as [spokenTitle], or "title, subtitle"
/// (`DL-138`); [toolbarHeight] then makes room for it, see
/// [kitSubtitleBarHeight].
AppBar kitAppBar({
  required String title,
  bool automaticallyImplyLeading = true,
  bool search = false,
  bool fadeTitle = false,
  bool titleFlight = false,
  String? subtitle,
  String? spokenTitle,
  double? toolbarHeight,
  List<Widget>? actions,
  Widget? leading,
  ValueListenable<double>? titleOpacity,
  ValueListenable<double>? edgeOpacity,
}) {
  final Text text = Text(
    title,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: KitColors.ink,
    ),
  );
  Widget heading = fadeTitle ? _FadingTitle(text) : text;
  if (subtitle != null) {
    heading = _TitleWithSubtitle(
      title: title,
      subtitle: subtitle,
      label: spokenTitle ?? '$title, $subtitle',
    );
  }
  if (titleOpacity != null) {
    final Widget shown = heading;
    heading = ValueListenableBuilder<double>(
      valueListenable: titleOpacity,
      child: shown,
      builder: (BuildContext context, double opacity, Widget? child) =>
          ExcludeSemantics(
            child: Opacity(
              key: const ValueKey<String>('kit-bar-title'),
              opacity: opacity,
              child: child,
            ),
          ),
    );
  }
  return AppBar(
    automaticallyImplyLeading: automaticallyImplyLeading,
    toolbarHeight: toolbarHeight,
    leading: leading,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    centerTitle: true,
    actions: <Widget>[if (search) const _SearchAction(), ...?actions],
    title: titleFlight ? FlightTarget(id: 'title', child: heading) : heading,
    bottom: edgeOpacity == null
        ? null
        : PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: ValueListenableBuilder<double>(
              valueListenable: edgeOpacity,
              builder: (BuildContext context, double opacity, Widget? _) =>
                  ExcludeSemantics(
                    child: Opacity(
                      key: const ValueKey<String>('kit-bar-edge'),
                      opacity: opacity,
                      child: const SizedBox(
                        height: 1,
                        width: double.infinity,
                        child: ColoredBox(color: KitColors.buttonOff),
                      ),
                    ),
                  ),
            ),
          ),
  );
}

/// The toolbar height a title with a [kitAppBar] subtitle needs at [scaler]:
/// 56 at least, else both lines at their scaled size with 8 around them.
double kitSubtitleBarHeight(TextScaler scaler) => math.max(
  56,
  8 +
      18 * 1.3 * textScaleAt(scaler, 18) +
      1 +
      12 * 1.3 * textScaleAt(scaler, 12),
);

/// The title and its subtitle as one heading; the lines shrink to the bar
/// rather than overflow it.
class _TitleWithSubtitle extends StatelessWidget {
  const _TitleWithSubtitle({
    required this.title,
    required this.subtitle,
    required this.label,
  });

  final String title;
  final String subtitle;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: label,
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: KitColors.ink,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.3,
                color: KitColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
