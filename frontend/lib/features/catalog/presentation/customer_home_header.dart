import 'package:flutter/material.dart';

import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../addresses/presentation/delivery_address_widgets.dart';
import '../../cart/presentation/cart_widgets.dart';

/// The top of the Customer's home (design 4a): the brand green under the
/// status bar with a curved bottom, the [search] beside the cart, and where
/// the order goes. The active mode shows at its top while two sessions
/// exist (`docs/02-user-roles.md` section 10).
class CustomerHomeHeader extends StatelessWidget {
  const CustomerHomeHeader({required this.search, this.modeAction, super.key});

  final Widget search;

  /// The active-mode bar's action (the way back to the staff area).
  final Widget? modeAction;

  /// How deep the bottom curve dips at its middle.
  static const double curveDepth = 46;

  /// The most of the screen's height the header takes before it scrolls.
  static const double maxShare = 0.45;

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.sizeOf(context).height * maxShare;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          DecoratedBox(
            decoration: BoxDecoration(
              color: BrandColors.green,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.elliptical(constraints.maxWidth / 2, curveDepth),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                // With large text on a small screen the header would leave
                // the sections no room: it stays within its share. The mode
                // bar yields first — it scrolls in what the search and the
                // address leave — so those two stay in sight.
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: SingleChildScrollView(
                          child: ActiveModeBar(action: modeAction),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxHeight),
                        child: SingleChildScrollView(
                          key: const ValueKey<String>('home-header-controls'),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  0,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(child: search),
                                    const SizedBox(width: 10),
                                    const CartButton(onBrand: true),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const DeliveryAddressLine(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }
}
