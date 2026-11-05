import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/layout/text_width.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/product_image.dart';
import '../../../core/widgets/rolling_amount.dart';
import '../../cart/application/card_quantity.dart';
import '../../cart/presentation/cart_line_stepper.dart';
import '../application/order_draft.dart';
import 'order_edit_words.dart';

const ColorFilter _grey = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// One line of the order's editor (`DL-132`). A kept line reads as one
/// container — its name, quantity and sum — with the stepper's buttons and the
/// options row as its own actions; a line taken out folds to a compact row
/// that says so and offers «Вернуть». The top of a kept line takes no tap: the
/// options row and the stepper's quantity open the sheet. The line's sum
/// rolls and stands beside the stepper, or over it when they do not fit.
class OrderEditLineTile extends StatelessWidget {
  const OrderEditLineTile({
    required this.draft,
    required this.adds,
    required this.busy,
    required this.onStep,
    required this.onQuantity,
    required this.onOptions,
    required this.onRemove,
    required this.onRestore,
    super.key,
  });

  final DraftLine draft;

  /// The line adds a product to the order, rather than keeping one in it.
  final bool adds;
  final bool busy;

  /// One step of the quantity (the minus at the minimum calls [onRemove]).
  final void Function({required bool up}) onStep;
  final VoidCallback onQuantity;
  final VoidCallback onOptions;
  final VoidCallback onRemove;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KitColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: draft.removed
            ? _RemovedRow(draft: draft, busy: busy, onRestore: onRestore)
            : _KeptLine(
                draft: draft,
                adds: adds,
                busy: busy,
                onStep: onStep,
                onQuantity: onQuantity,
                onOptions: onOptions,
                onRemove: onRemove,
              ),
      ),
    );
  }
}

/// The picture box of a line: [size] square, the picture in it [inner]
/// square, greyed and faint for a line taken out.
class _Picture extends StatelessWidget {
  const _Picture({
    required this.url,
    required this.size,
    required this.inner,
    required this.radius,
    this.grey = false,
  });

  final String? url;
  final double size;
  final double inner;
  final double radius;
  final bool grey;

  @override
  Widget build(BuildContext context) {
    final Widget image = ProductImage(url: url, size: inner);
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KitColors.card,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Center(
          child: grey
              ? Opacity(
                  opacity: 0.4,
                  child: ColorFiltered(colorFilter: _grey, child: image),
                )
              : image,
        ),
      ),
    );
  }
}

class _KeptLine extends StatelessWidget {
  const _KeptLine({
    required this.draft,
    required this.adds,
    required this.busy,
    required this.onStep,
    required this.onQuantity,
    required this.onOptions,
    required this.onRemove,
  });

  final DraftLine draft;
  final bool adds;
  final bool busy;
  final void Function({required bool up}) onStep;
  final VoidCallback onQuantity;
  final VoidCallback onOptions;
  final VoidCallback onRemove;

  static const TextStyle _sumStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: KitColors.ink,
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final bool wrapOptions =
        textScaleAt(MediaQuery.textScalerOf(context), 13) > 1.3;
    final String unit = CatalogLabels.unit(l10n, draft.unit);
    final int? preview = draft.previewUzs;
    final String options = optionsWords(l10n, draft);

    String amount(int uzs) => estimatedAmount(l10n, draft, language, uzs);

    final Widget top = ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Picture(url: draft.imageUrl, size: 56, inner: 44, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  draft.name(language),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: KitColors.ink,
                  ),
                ),
                if (adds)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: DecoratedBox(
                      key: ValueKey<String>('edit-adds-${draft.key}'),
                      decoration: BoxDecoration(
                        color: KitColors.primaryWash,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Text(
                          l10n.orderEditNew,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: KitColors.primaryDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  perUnitWords(l10n, draft, language, unit),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: KitColors.muted),
                ),
                if (draft.unavailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.cartLineUnavailable,
                      key: ValueKey<String>('edit-unavailable-${draft.key}'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: KitColors.danger,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final Widget optionsRow = Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Semantics(
        button: true,
        label: l10n.orderEditOptionsSpoken(options),
        onTap: busy ? null : onOptions,
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey<String>('edit-options-${draft.key}'),
          onTap: busy ? null : onOptions,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: wrapOptions ? 0 : 68),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.edit_note,
                    size: 18,
                    color: KitColors.primaryDark,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      options,
                      maxLines: wrapOptions ? null : 1,
                      // An ellipsis would cut the words to one line.
                      overflow: wrapOptions
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: KitColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: KitColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    /// The bottom row: the sum beside the stepper or, when they do not fit,
    /// over it, as the cart's line (`DL-119` (4)).
    Widget bottom(double width) {
      Widget stepper(double stepperWidth) => CartLineStepper(
        id: draft.key,
        quantityText: quantityWords(l10n, draft.unit, draft.quantity),
        busy: busy,
        canStep: draft.quantityValid,
        atMinimum:
            draft.quantityValid &&
            CardQuantity.previous(draft.unit, draft.quantity) == null,
        width: stepperWidth,
        onMinus:
            draft.quantityValid &&
                CardQuantity.previous(draft.unit, draft.quantity) == null
            ? onRemove
            : () => onStep(up: false),
        onPlus: () => onStep(up: true),
        onQuantity: onQuantity,
      );
      if (preview == null) {
        return Align(
          alignment: AlignmentDirectional.centerEnd,
          child: stepper(CartLineStepper.defaultWidth),
        );
      }
      final Widget sum = ExcludeSemantics(
        child: RollingAmount(
          amountUzs: preview,
          format: amount,
          style: _sumStyle,
          textKey: ValueKey<String>('edit-sum-${draft.key}'),
        ),
      );
      final double sumWidth = textWidth(context, amount(preview), _sumStyle);
      if (sumWidth + 8 + CartLineStepper.defaultWidth <= width) {
        return Row(
          children: <Widget>[
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: sum),
            ),
            const SizedBox(width: 8),
            stepper(CartLineStepper.defaultWidth),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          sum,
          const SizedBox(height: 6),
          stepper(math.min(180, width)),
        ],
      );
    }

    return Semantics(
      key: ValueKey<String>('edit-line-${draft.key}'),
      container: true,
      explicitChildNodes: true,
      label: lineSpoken(l10n, language, draft, adds: adds),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            top,
            optionsRow,
            const SizedBox(height: 6),
            bottom(constraints.maxWidth),
          ],
        ),
      ),
    );
  }
}

/// The compact row of a line taken out: what happened, and «Вернуть».
class _RemovedRow extends StatelessWidget {
  const _RemovedRow({
    required this.draft,
    required this.busy,
    required this.onRestore,
  });

  final DraftLine draft;
  final bool busy;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final String name = draft.name(language);
    final String words = l10n.orderEditRemoved(name);
    final int at = words.indexOf(name);
    const TextStyle base = TextStyle(
      fontSize: 13,
      height: 1.35,
      color: KitColors.muted,
    );
    const TextStyle bold = TextStyle(
      fontWeight: FontWeight.w600,
      color: KitColors.ink2,
    );

    final Widget row = ConstrainedBox(
      key: ValueKey<String>('edit-removed-${draft.key}'),
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: <Widget>[
          ExcludeSemantics(
            child: _Picture(
              url: draft.imageUrl,
              size: 36,
              inner: 28,
              radius: 10,
              grey: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ExcludeSemantics(
              child: Text.rich(
                TextSpan(
                  style: base,
                  children: at < 0
                      ? <InlineSpan>[TextSpan(text: words)]
                      : <InlineSpan>[
                          TextSpan(text: words.substring(0, at)),
                          TextSpan(text: name, style: bold),
                          TextSpan(text: words.substring(at + name.length)),
                        ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: KitColors.primaryWash,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              key: ValueKey<String>('edit-restore-${draft.key}'),
              borderRadius: BorderRadius.circular(22),
              onTap: busy ? null : onRestore,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        l10n.orderEditKeepLine,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: KitColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      key: ValueKey<String>('edit-line-${draft.key}'),
      container: true,
      explicitChildNodes: true,
      label: words,
      child: _FadeIn(child: row),
    );
  }
}

/// With reduced motion the new row fades from 0.35 in 220 ms; otherwise the
/// line's height moves and the row is still (`DL-132`).
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.35, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (BuildContext context, double opacity, Widget? child) =>
          Opacity(opacity: opacity, child: child),
      child: child,
    );
  }
}
