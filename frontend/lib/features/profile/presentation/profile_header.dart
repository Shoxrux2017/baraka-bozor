import 'package:flutter/material.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../cart/presentation/cart_widgets.dart';
import '../domain/profile.dart';
import 'initials.dart';

/// The green head of the profile tab (kit drawings 32 and 32а): the title,
/// the avatar with the initials, the name and the phone. The inset of the
/// status bar belongs to the screen.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({required this.profile, super.key});

  final CustomerProfile profile;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? name = profile.fullName;
    final String? initials = initialsOf(name);
    final bool hasName = name != null && name.trim().isNotEmpty;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: KitColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.elliptical(30, 22)),
      ),
      child: Padding(
        // The title row is 44 high and runs to the screen's edges, so the
        // paddings around it give back what it took: the header keeps the
        // height it had (`DL-118`).
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Semantics(
                        header: true,
                        child: Center(
                          child: Text(
                            l10n.profileTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 0,
                    right: 10,
                    child: CartButton(onBrand: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 70,
                    height: 70,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: KitColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: initials == null
                        ? const Icon(
                            Icons.person,
                            size: 36,
                            color: KitColors.primaryDark,
                          )
                        : Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: KitColors.primaryDark,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Opacity(
                          opacity: hasName ? 1 : 0.9,
                          child: Text(
                            hasName ? name : l10n.profileNoName,
                            key: const ValueKey<String>('profile-name'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatPhone(profile.phone),
                          key: const ValueKey<String>('profile-phone'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
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
