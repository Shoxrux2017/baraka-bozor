import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit_app_bar.dart';

/// What follows a completed shopping (`docs/04` section 22, W3-16): the
/// order is the Shopper's no more, so the screen stands on its own, puts the
/// order number large — it is written by hand on the package — says to take
/// the package to the handoff point, and back leads to their list.
class ShopperDoneScreen extends StatelessWidget {
  const ShopperDoneScreen({required this.orderNumber, super.key});

  final int orderNumber;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) {
          context.go(AppPaths.shopper);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: kitAppBar(
          title: l10n.shellShopper,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              const ActiveModeBar(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Center(child: _Halo()),
                          const SizedBox(height: 24),
                          Text(
                            l10n.doneTitle('$orderNumber'),
                            key: const ValueKey<String>('shopper-done-title'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: KitColors.ink,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _BagBox(
                            caption: l10n.doneWriteOnBag,
                            number: '$orderNumber',
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.doneLabel,
                            key: const ValueKey<String>('shopper-done-label'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: KitColors.ink2,
                            ),
                          ),
                          const SizedBox(height: 28),
                          FilledButton(
                            key: const ValueKey<String>('shopper-done-back'),
                            style: kitFilled(),
                            onPressed: () => context.go(AppPaths.shopper),
                            child: Text(l10n.doneBack),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A green circle with a tick inside a paler halo.
class _Halo extends StatelessWidget {
  const _Halo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: KitColors.primaryWash,
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 84,
        height: 84,
        decoration: const BoxDecoration(
          color: KitColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 44, color: Colors.white),
      ),
    );
  }
}

/// The box that stands for the package: a dashed green border, the call to
/// write, and the number, scaled down only when it does not fit.
class _BagBox extends StatelessWidget {
  const _BagBox({required this.caption, required this.number});

  final String caption;
  final String number;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: const _DashedBorder(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: KitColors.primaryWash,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: KitColors.primaryDark,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: KitColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: KitColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 2 px dashed outline of the kit's green on a rounded rectangle.
class _DashedBorder extends CustomPainter {
  const _DashedBorder();

  static const double _dash = 8;
  static const double _gap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = KitColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final Path outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(18),
        ).deflate(1),
      );
    for (final PathMetric metric in outline.computeMetrics()) {
      double at = 0;
      while (at < metric.length) {
        canvas.drawPath(metric.extractPath(at, at + _dash), paint);
        at += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => false;
}
