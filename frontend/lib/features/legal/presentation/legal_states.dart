import 'package:flutter/material.dart';

import '../../../core/layout/text_width.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit/quiet_icon.dart';
import '../../../core/widgets/skeleton_bar.dart';

/// What stands under the large title while the document is not known yet:
/// a date bar and three groups of a heading bar over four lines (`DL-136`
/// (4)). It reads «Загружаем документ…» and nothing else; heights and gaps
/// follow the text size.
class LegalSkeleton extends StatelessWidget {
  const LegalSkeleton({super.key});

  static const List<double> _lines = <double>[1, 0.96, 0.92, 0.6];

  @override
  Widget build(BuildContext context) {
    final double scale = textScaleAt(MediaQuery.textScalerOf(context), 16);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: l10n.legalLoadingSpoken,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          Widget bar(double fraction, double height) => SkeletonBar(
            width: width * fraction,
            height: height * scale,
            radius: 6,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              bar(0.4, 13),
              for (int group = 0; group < 3; group++) ...<Widget>[
                SizedBox(height: 26 * scale),
                bar(0.55, 16),
                SizedBox(height: 14 * scale),
                for (final double line in _lines) ...<Widget>[
                  bar(line, 12),
                  SizedBox(height: 14 * scale),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// A state with nothing to read, in the middle of the body: a [QuietIcon], a
/// [title], the [body] words and one [button]. It scrolls when it is taller
/// than the screen; [controller] is the page's, so the bar's hairline follows.
class LegalStatePanel extends StatelessWidget {
  const LegalStatePanel({
    required this.controller,
    required this.icon,
    required this.title,
    required this.body,
    required this.button,
    super.key,
  });

  final ScrollController controller;
  final IconData icon;
  final String title;
  final String body;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final bool landscape = media.orientation == Orientation.landscape;
    final double side = landscape ? 80 : 32;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          key: const ValueKey<String>('legal-scroll'),
          controller: controller,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  side + media.padding.left,
                  16,
                  side + media.padding.right,
                  48 + media.padding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    QuietIcon(icon: icon),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: KitColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(
                        body,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: KitColors.ink2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    button,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The state's one button, 200 x 52 at least with a 14 radius: green with
/// white text, or with [outlined] white with a 1 px frame. With a [busyLabel]
/// it shows a white spinner and that label, takes no tap and reads the label.
class LegalButton extends StatelessWidget {
  const LegalButton({
    required this.label,
    required this.onTap,
    this.outlined = false,
    this.busyLabel,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool outlined;
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    final String? busy = busyLabel;
    final Color ink = outlined ? KitColors.ink : Colors.white;
    final TextStyle style = TextStyle(
      fontSize: 16,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: ink,
    );
    final Widget face = busy == null
        ? Text(label, textAlign: TextAlign.center, style: style)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: ink),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(busy, textAlign: TextAlign.center, style: style),
              ),
            ],
          );
    final Widget content = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Center(widthFactor: 1, child: face),
      ),
    );
    return Material(
      color: outlined ? Colors.white : KitColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: outlined
            ? const BorderSide(color: KitColors.outline)
            : BorderSide.none,
      ),
      child: busy == null
          ? Semantics(
              button: true,
              child: InkWell(
                customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onTap: onTap,
                child: content,
              ),
            )
          : Semantics(label: busy, excludeSemantics: true, child: content),
    );
  }
}
