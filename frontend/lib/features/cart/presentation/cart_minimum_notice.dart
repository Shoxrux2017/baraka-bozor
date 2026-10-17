import 'package:flutter/material.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/theme/kit_colors.dart';
import '../domain/cart.dart';

/// What is missing to the minimum order (drawing 19в), shown only while the
/// subtotal is short of it. The amounts are the server's; the bar is the
/// only figure drawn from them, and it is never printed.
class CartMinimumNotice extends StatelessWidget {
  const CartMinimumNotice({required this.cart, super.key});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    final int? minimum = cart.minimumOrderUzs;
    final int? shortfall = cart.minimumShortfallUzs;
    if (!cart.belowMinimum || minimum == null || shortfall == null) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final String missing = l10n.cartLineEstimate(
      MoneyFormat.uzs(shortfall, language),
    );
    final String sentence = l10n.cartMinimumShort(missing);
    final int at = sentence.indexOf(missing);
    const TextStyle plain = TextStyle(
      fontSize: 14,
      height: 1.35,
      color: KitColors.ink,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DecoratedBox(
        key: const ValueKey<String>('cart-minimum'),
        decoration: BoxDecoration(
          color: KitColors.primaryWash,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text.rich(
                at < 0
                    ? TextSpan(text: sentence, style: plain)
                    : TextSpan(
                        style: plain,
                        children: <InlineSpan>[
                          TextSpan(text: sentence.substring(0, at)),
                          TextSpan(
                            text: missing,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: sentence.substring(at + missing.length),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                key: const ValueKey<String>('cart-minimum-bar'),
                value: (minimum - shortfall) / minimum,
                minHeight: 6,
                color: KitColors.primary,
                backgroundColor: KitColors.primarySoft,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.cartMinimumRule(MoneyFormat.uzs(minimum, language)),
                style: const TextStyle(fontSize: 11, color: KitColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
