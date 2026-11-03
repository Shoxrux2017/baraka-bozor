import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/product_image.dart';
import '../application/cart_controllers.dart';
import '../domain/cart.dart';
import 'cart_paths.dart';

/// The green bar at the foot of a product list without the tab bar while the
/// cart holds a line (`DL-80` (3), `DL-127`): the last line's picture, how many
/// lines, the approximate total, and the way to the cart. Place it at the
/// bottom of a stack; it takes no room when the cart is empty. The first line
/// slides it up, an emptied cart slides it down (a fade with reduced motion);
/// a new total rolls in and a new last line's picture comes in. At large text
/// an arrow replaces the words and the count and the total may take two lines.
/// While [hidden] it leaves as an emptied cart's bar does and comes back as a
/// first line's does, so a screen can clear the way for the keyboard
/// (`DL-128`).
class CartSummaryBar extends ConsumerStatefulWidget {
  const CartSummaryBar({this.hidden = false, super.key});

  final bool hidden;

  /// The room the bar and its fade take at the foot of a list: the bar's
  /// own height at the current text scale, its paddings, and the bottom
  /// inset of the screen.
  static double reserved(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double lines = _isLarge(scaler) ? 2 : 1;
    final double count = scaler.scale(12) * 1.5 * lines;
    final double total = scaler.scale(15) * 1.5 * lines;
    final double open = _isLarge(scaler) ? 30 : scaler.scale(14) * 1.5 * 2;
    final double content = math.max(46, math.max(count + total, open));
    final double bar = math.max(64, content + 16);
    return 24 + bar + 12 + MediaQuery.paddingOf(context).bottom;
  }

  /// Whether the text is large enough that the arrow replaces the words.
  static bool _isLarge(TextScaler scaler) => textScaleAt(scaler, 14) > 1.3;

  @override
  ConsumerState<CartSummaryBar> createState() => _CartSummaryBarState();
}

class _CartSummaryBarState extends ConsumerState<CartSummaryBar>
    with SingleTickerProviderStateMixin {
  static const Cubic _up = Cubic(0.2, 0.8, 0.2, 1);
  static const Cubic _down = Cubic(0.4, 0, 1, 1);

  late final AnimationController _slide = AnimationController(vsync: this)
    ..addStatusListener(_settled);
  late final Animation<double> _position = CurvedAnimation(
    parent: _slide,
    curve: _up,
    reverseCurve: const FlippedCurve(_down),
  );

  /// The last cart that held lines: what the bar shows while it leaves.
  Cart? _shown;

  @override
  void initState() {
    super.initState();
    final Cart? cart = ref.read(currentCartProvider).value;
    if (!widget.hidden && cart != null && cart.lines.isNotEmpty) {
      _shown = cart;
      _slide.value = 1;
    }
    ref.listenManual(currentCartProvider, _follow);
  }

  @override
  void didUpdateWidget(CartSummaryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hidden != oldWidget.hidden) {
      _run(ref.read(currentCartProvider).value);
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  void _follow(AsyncValue<Cart>? previous, AsyncValue<Cart> next) {
    final Cart? cart = next.value;
    if (cart == null) {
      // Another account, or none: the last cart is not shown to it.
      setState(() => _shown = null);
      _slide.value = 0;
      return;
    }
    _run(cart);
  }

  /// Slides the bar in when [cart] holds a line and the bar is not hidden, and
  /// out otherwise; it keeps the last cart that held lines while it leaves.
  void _run(Cart? cart) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    _slide.duration = Duration(milliseconds: reduced ? 200 : 360);
    _slide.reverseDuration = Duration(milliseconds: reduced ? 200 : 240);
    if (cart != null && cart.lines.isNotEmpty) {
      if (!widget.hidden) {
        _shown = cart;
        _slide.forward();
        if (mounted) {
          setState(() {});
        }
        return;
      }
      if (_shown != null) {
        _shown = cart;
      }
    }
    _slide.reverse();
    if (_slide.isDismissed && _shown != null) {
      setState(() => _shown = null);
    }
  }

  void _settled(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _shown != null) {
      setState(() => _shown = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Cart? cart = _shown;
    if (cart == null) {
      return const SizedBox.shrink();
    }

    final AppLocalizations l10n = AppLocalizations.of(context);
    final MediaQueryData media = MediaQuery.of(context);
    final bool reduced = media.disableAnimations;
    final bool large = CartSummaryBar._isLarge(media.textScaler);
    final CartLine last = cart.lines.last;
    final String sum = MoneyFormat.uzs(
      cart.estimatedSubtotalUzs,
      interfaceLanguage(context),
    );
    final AppLanguage language = interfaceLanguage(context);
    // The currency may drop to a second line; the amount stays whole.
    final String total = l10n.catalogApproxPrice(
      '${MoneyFormat.grouped(cart.estimatedSubtotalUzs)} '
      '${MoneyFormat.currency(language)}',
    );
    final String open = '${l10n.cartSummaryOpen} →';
    const TextStyle totalStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );
    const TextStyle openStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );

    final Widget bar = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x00FFFFFF), Colors.white],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20 + media.padding.left,
          24,
          20 + media.padding.right,
          12 + media.padding.bottom,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: KitColors.primary.withValues(alpha: 0.35),
                offset: Offset(0, 6),
                blurRadius: 18,
              ),
            ],
          ),
          child: Semantics(
            button: true,
            label: l10n.cartSummarySpoken(
              l10n.cartSummaryCount(cart.itemCount),
              sum,
            ),
            excludeSemantics: true,
            onTap: () => context.push(CartPaths.cart),
            child: Material(
              key: const ValueKey<String>('cart-summary'),
              color: KitColors.primary,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push(CartPaths.cart),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints box) {
                        // The words take at most half of the room after the
                        // picture; the arrow replaces them when the sum would not
                        // fit in what they leave.
                        final double rest = box.maxWidth - 46 - 10;
                        final double wordsMax = rest / 2;
                        final double words = math.min(
                          textWidth(context, open, openStyle) + 8,
                          wordsMax,
                        );
                        final bool arrow =
                            large ||
                            textWidth(context, total, totalStyle) >
                                rest - 8 - words;
                        return Row(
                          children: <Widget>[
                            SizedBox.square(
                              dimension: 46,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Center(
                                    child: _Swap(
                                      swapKey: last.id,
                                      duration: 260,
                                      reduced: reduced,
                                      scaleFrom: 0.7,
                                      child: ProductImage(
                                        url: last.imageUrl,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    l10n.cartSummaryCount(cart.itemCount),
                                    maxLines: large ? 2 : 1,
                                    overflow: large
                                        ? TextOverflow.clip
                                        : TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                  _Swap(
                                    swapKey: total,
                                    duration: 240,
                                    reduced: reduced,
                                    riseFrom: 0.45,
                                    child: Text(
                                      total,
                                      maxLines: arrow ? 2 : 1,
                                      overflow: TextOverflow.clip,
                                      style: totalStyle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (arrow)
                              const ExcludeSemantics(
                                child: Icon(
                                  Icons.chevron_right,
                                  size: 30,
                                  color: Colors.white,
                                ),
                              )
                            else
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: wordsMax),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    open,
                                    maxLines: 2,
                                    textAlign: TextAlign.end,
                                    overflow: TextOverflow.ellipsis,
                                    style: openStyle,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (reduced) {
      return FadeTransition(opacity: _position, child: bar);
    }
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(_position),
      child: bar,
    );
  }
}

/// Shows [child] and, when [swapKey] changes, brings the new child in with
/// `Curves.easeOut` while the old one goes: from [scaleFrom], or from [riseFrom]
/// of its height below, always with a fade. With reduced motion only a 200 ms
/// fade remains (`DL-127`).
class _Swap extends StatelessWidget {
  const _Swap({
    required this.swapKey,
    required this.duration,
    required this.reduced,
    required this.child,
    this.scaleFrom,
    this.riseFrom,
  });

  final Object swapKey;
  final int duration;
  final bool reduced;
  final double? scaleFrom;
  final double? riseFrom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduced ? 200 : duration),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: <Widget>[...previous, ?current],
      ),
      transitionBuilder: (Widget child, Animation<double> animation) {
        Widget moved = child;
        final double? scale = scaleFrom;
        final double? rise = riseFrom;
        if (!reduced && scale != null) {
          moved = ScaleTransition(
            scale: Tween<double>(begin: scale, end: 1).animate(animation),
            child: moved,
          );
        }
        if (!reduced && rise != null) {
          moved = SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, rise),
              end: Offset.zero,
            ).animate(animation),
            child: moved,
          );
        }
        return FadeTransition(opacity: animation, child: moved);
      },
      child: KeyedSubtree(key: ValueKey<Object>(swapKey), child: child),
    );
  }
}
