import 'package:flutter/material.dart';

import '../../../core/formatting/server_text.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/fold.dart';
import '../../../core/widgets/soft_change.dart';
import '../../cart/presentation/cart_widgets.dart';

/// "В корзине: 2 кг" above the name; the quantity rises softly when it
/// changes (`DL-122`).
class ProductInCartChip extends StatelessWidget {
  const ProductInCartChip({required this.quantity, super.key});

  /// The line's quantity as it is written, unit included: `2 кг`.
  final String quantity;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.primarySoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.shopping_bag_outlined,
              size: 16,
              color: KitColors.primaryDark,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: SoftChange(
                value: quantity,
                child: Text(
                  l10n.productInCart(quantity),
                  key: const ValueKey<String>('product-in-cart'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: KitColors.primaryDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the last change of a line in the cart stands (`DL-122`).
enum ProductSaveState { saving, saved }

/// The small mark beside a field that says its change is on its way or kept:
/// a spinner and «Сохраняем…», then a check and «Сохранено». It fades in over
/// 200 ms, and a screen reader hears it as a live region.
class ProductSaveMark extends StatelessWidget {
  const ProductSaveMark({required this.state, super.key});

  final ProductSaveState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool saving = state == ProductSaveState.saving;
    final Color colour = saving ? KitColors.muted : KitColors.primaryDark;
    final Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExcludeSemantics(
          child: saving
              ? SizedBox.square(
                  dimension: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: KitColors.primary,
                    backgroundColor: KitColors.primary.withValues(alpha: 0.2),
                  ),
                )
              : Icon(Icons.check, size: 16, color: colour),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            saving ? l10n.productSaving : l10n.productLineSaved,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colour,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      liveRegion: true,
      child: MediaQuery.disableAnimationsOf(context)
          ? row
          : TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              builder: (BuildContext context, double opacity, Widget? child) =>
                  Opacity(opacity: opacity, child: child),
              child: row,
            ),
    );
  }
}

/// The note to the Shopper (`DL-122`): three to five lines, a green border
/// while it is typed in, a red one and the reason as soon as it is too long,
/// as the server counts it. Under it a row holds the reason, the [mark] and
/// from 250 characters the count. A tap outside closes the keyboard.
class ProductNoteField extends StatelessWidget {
  const ProductNoteField({
    required this.controller,
    required this.focusNode,
    required this.readOnly,
    this.onChanged,
    this.mark,
    super.key,
  });

  /// The length from which the counter is shown.
  static const int counterFrom = 250;

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool readOnly;

  /// Called with the text after the Customer changed it.
  final ValueChanged<String>? onChanged;

  /// The save mark in the footer row, when there is one.
  final ProductSaveState? mark;

  static OutlineInputBorder _border(Color? colour) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: colour == null
        ? BorderSide.none
        : BorderSide(color: colour, width: 1.5),
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[controller, focusNode]),
      builder: (BuildContext context, Widget? _) {
        final int length = trimLikeServer(controller.text).runes.length;
        final bool over = length > cartNoteMaxLength;
        final OutlineInputBorder resting = _border(
          over ? KitColors.danger : null,
        );
        final OutlineInputBorder focused = _border(
          over ? KitColors.danger : KitColors.primary,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('line-note'),
              controller: controller,
              focusNode: focusNode,
              readOnly: readOnly,
              onChanged: onChanged,
              minLines: 3,
              maxLines: 5,
              onTapOutside: (PointerDownEvent _) => focusNode.unfocus(),
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: KitColors.ink,
              ),
              decoration: InputDecoration(
                hintText: l10n.productNoteHint,
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: KitColors.muted,
                ),
                filled: true,
                fillColor: KitColors.field,
                contentPadding: const EdgeInsets.all(14),
                border: resting,
                enabledBorder: resting,
                focusedBorder: focused,
              ),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        if (over)
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              l10n.fieldTooLong(cartNoteMaxLength),
                              key: const ValueKey<String>('product-note-error'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: KitColors.danger,
                              ),
                            ),
                          ),
                        if (mark != null)
                          ProductSaveMark(
                            key: const ValueKey<String>(
                              'product-save-mark-note',
                            ),
                            state: mark!,
                          ),
                      ],
                    ),
                  ),
                  if (length >= counterFrom)
                    Text(
                      '$length / $cartNoteMaxLength',
                      key: const ValueKey<String>('product-note-count'),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12,
                        color: over ? KitColors.danger : KitColors.muted,
                        fontWeight: over ? FontWeight.w600 : null,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The estimate in two short lines and a «Как считаем» that unfolds the full
/// text and closes it again (`DL-122`).
class ProductEstimate extends StatefulWidget {
  const ProductEstimate({super.key});

  @override
  State<ProductEstimate> createState() => _ProductEstimateState();
}

class _ProductEstimateState extends State<ProductEstimate> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.primaryWash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.info_outline, size: 20, color: KitColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.productEstimateTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: KitColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.productEstimatePromise,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: KitColors.ink2,
                    ),
                  ),
                  Fold(
                    shown: _open,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        l10n.catalogEstimateExplain,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: KitColors.ink2,
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    expanded: _open,
                    child: InkWell(
                      key: const ValueKey<String>('product-estimate-how'),
                      onTap: () => setState(() => _open = !_open),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                _open
                                    ? l10n.productReadLess
                                    : l10n.productEstimateHow,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: KitColors.primaryDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: _open ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.ease,
                              child: const Icon(
                                Icons.expand_more,
                                size: 18,
                                color: KitColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
