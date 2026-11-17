import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/skeleton_bar.dart';

/// What the search under the field came to (`DL-138`).
enum SearchFace { found, notFound, unavailable }

/// The answer to a search, right under the field: the point was found, or
/// nothing was, or the search is down. The query stands bold in the first
/// two; [keptLine] is the promise that the words travel with the address.
/// It comes in by opacity and a rise of 6, by opacity only with reduced
/// motion, each time [serial] changes.
class SearchAnswer extends StatefulWidget {
  const SearchAnswer({
    required this.face,
    required this.query,
    required this.serial,
    this.keptLine,
    super.key,
  });

  final SearchFace face;
  final String query;
  final int serial;
  final String? keptLine;

  @override
  State<SearchAnswer> createState() => _SearchAnswerState();
}

class _SearchAnswerState extends State<SearchAnswer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  late final CurvedAnimation _eased = CurvedAnimation(
    parent: _controller,
    curve: const Cubic(0.2, 0.8, 0.2, 1),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _play();
    }
  }

  @override
  void didUpdateWidget(SearchAnswer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serial != widget.serial) {
      _play();
    }
  }

  void _play() {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    _controller.duration = Duration(milliseconds: reduced ? 200 : 220);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _eased.dispose();
    _controller.dispose();
    super.dispose();
  }

  List<InlineSpan> _spans(String template) {
    const String mark = '\u0000';
    final List<String> parts = template.split(mark);
    if (parts.length != 2) {
      return <InlineSpan>[TextSpan(text: template)];
    }
    return <InlineSpan>[
      TextSpan(text: parts[0]),
      TextSpan(
        text: widget.query,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: KitColors.ink,
        ),
      ),
      TextSpan(text: parts[1]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    const String mark = '\u0000';
    final bool found = widget.face == SearchFace.found;
    final String template = switch (widget.face) {
      SearchFace.found => l10n.addressSearchFoundAt(mark),
      SearchFace.notFound => l10n.addressSearchNotFoundAt(mark),
      SearchFace.unavailable => l10n.addressSearchDown,
    };
    final IconData icon = switch (widget.face) {
      SearchFace.found => Icons.check_circle,
      SearchFace.notFound => Icons.travel_explore,
      SearchFace.unavailable => Icons.cloud_off,
    };
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final Animation<double> eased = _eased;
    return AnimatedBuilder(
      animation: eased,
      builder: (BuildContext context, Widget? child) => Opacity(
        opacity: eased.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, reduced ? 0 : -6 * (1 - eased.value)),
          child: child,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: found ? Colors.white : KitColors.warningWash,
          borderRadius: BorderRadius.circular(12),
          boxShadow: found
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x1F151D16),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: found ? KitColors.primary : KitColors.warningDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: KitColors.ink2,
                        ),
                        children: _spans(template),
                      ),
                    ),
                    if (widget.keptLine != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        widget.keptLine!,
                        key: const ValueKey<String>('address-words-kept'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: KitColors.primaryDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The panel's first row: the address the map names under the pin. While it
/// looks, [line] is null and a bar stands in; the row is a live region that
/// reads the same words (`DL-138`).
class PlaceRow extends StatelessWidget {
  const PlaceRow({this.line, this.sub, super.key});

  final String? line;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? shown = line;
    final String? under = sub;
    return Semantics(
      container: true,
      liveRegion: true,
      excludeSemantics: true,
      label: shown == null
          ? l10n.addressPlaceLooking
          : under == null
          ? shown
          : '$shown. $under',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.location_on, size: 24, color: KitColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: shown == null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FractionallySizedBox(
                          widthFactor: 0.62,
                          child: LayoutBuilder(
                            builder: (BuildContext context, BoxConstraints c) =>
                                SkeletonBar(
                                  width: c.maxWidth,
                                  height: 16,
                                  radius: 6,
                                ),
                          ),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          shown,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                            color: KitColors.ink,
                          ),
                        ),
                        if (under != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            under,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: KitColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The red box of the panel: the pin is outside the delivery zone, how far,
/// and what to do (`DL-138`).
class ZoneNotice extends StatelessWidget {
  const ZoneNotice({required this.distance, required this.radius, super.key});

  final String distance;
  final String radius;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.dangerWash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.wrong_location, size: 20, color: KitColors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.addressOutsideZone(distance, radius),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  color: KitColors.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
