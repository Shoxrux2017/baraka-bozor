import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/session_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/skeleton_bar.dart';
import '../../cart/presentation/cart_widgets.dart';
import '../domain/profile.dart';
import 'initials.dart';

/// The dark green head of the profile tab (kit drawings 32 and 32а): the
/// title, the mode pill while two sessions exist, and under them one of three
/// faces (`DL-135`). With a profile, the avatar, the name and the phone, all
/// of it the button that opens the name editor. Without one, a skeleton while
/// it loads, or the offline face with a retry when it failed. The inset of the
/// status bar belongs to the screen.
///
/// Each new value of [arrival] above 0 plays the arrival of a saved name: the
/// name rises and the button flashes.
class ProfileHeader extends ConsumerStatefulWidget {
  const ProfileHeader({
    required this.profile,
    required this.onEdit,
    required this.onRetry,
    required this.arrival,
    super.key,
  });

  final AsyncValue<CustomerProfile> profile;
  final VoidCallback onEdit;
  final VoidCallback onRetry;
  final int arrival;

  @override
  ConsumerState<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends ConsumerState<ProfileHeader>
    with TickerProviderStateMixin {
  static const Color _clear = Color(0x00FFFFFF);

  /// The identity replacing a skeleton or the offline face: 260 ms.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  /// The new name rising: 450 ms.
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    value: 1,
  );

  /// The button's flash: 1.5 s.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
    value: 1,
  );

  bool _held = false;

  @override
  void didUpdateWidget(ProfileHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    if (!oldWidget.profile.hasValue && widget.profile.hasValue) {
      _enter.forward(from: 0);
    }
    if (widget.arrival != oldWidget.arrival && widget.arrival > 0) {
      _rise.forward(from: 0);
      _flash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _rise.dispose();
    _flash.dispose();
    super.dispose();
  }

  void _hold(bool held) {
    if (_held != held) {
      setState(() => _held = held);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SessionState? session = ref.watch(sessionControllerProvider).value;
    final bool twoSessions =
        session is SignedIn &&
        session.staffUser != null &&
        session.customerUser != null;
    final CustomerProfile? data = widget.profile.value;

    // The title row is 44 high and runs to the screen's edges; the faces'
    // gaps below it count from the title's text, 10 above the row's end
    // (`DL-118`, `DL-135`).
    final Widget face;
    if (data != null) {
      face = Padding(
        padding: EdgeInsets.only(top: twoSessions ? 12 : 2),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _enter, curve: Curves.easeOut),
          child: _identity(context, l10n, data),
        ),
      );
    } else {
      // A retry after a failure loads again: the skeleton shows until it
      // answers.
      final Widget content = widget.profile.isLoading
          ? _skeleton(l10n)
          : _failure(l10n, widget.profile.error);
      face = Padding(
        padding: EdgeInsets.only(top: twoSessions ? 20 : 10, bottom: 8),
        child: content,
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: KitColors.primaryDark,
        borderRadius: BorderRadius.vertical(bottom: Radius.elliptical(30, 22)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _titleRow(l10n),
            if (twoSessions)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Center(child: _modePill(l10n)),
              ),
            face,
          ],
        ),
      ),
    );
  }

  Widget _titleRow(AppLocalizations l10n) {
    return SizedBox(
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
          const Positioned(top: 0, right: 10, child: CartButton(onBrand: true)),
        ],
      ),
    );
  }

  Widget _modePill(AppLocalizations l10n) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.headerPill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.shopping_basket_outlined,
                size: 17,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.customerModeLabel,
                  key: const ValueKey<String>('active-mode'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _identity(
    BuildContext context,
    AppLocalizations l10n,
    CustomerProfile data,
  ) {
    final String? name = data.fullName;
    final bool hasName = name != null && name.trim().isNotEmpty;
    final String? initials = initialsOf(name);
    final String phone = formatPhone(data.phone);
    final bool large = textScaleAt(MediaQuery.textScalerOf(context), 16) > 1.3;
    final bool still = MediaQuery.disableAnimationsOf(context);

    final Widget nameText = Opacity(
      opacity: hasName ? 1 : 0.9,
      child: Text(
        hasName ? name : l10n.profileNoName,
        key: const ValueKey<String>('profile-name'),
        maxLines: large ? null : 1,
        overflow: large ? TextOverflow.visible : TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Semantics(
        key: const ValueKey<String>('profile-identity'),
        container: true,
        button: true,
        excludeSemantics: true,
        label: l10n.profileHeaderSpoken(
          hasName ? name : l10n.profileNoNameSpoken,
          phone,
          hasName ? l10n.profileChangeName : l10n.profileSetName,
        ),
        onTap: widget.onEdit,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onEdit,
          onTapDown: (_) => _hold(true),
          onTapUp: (_) => _hold(false),
          onTapCancel: () => _hold(false),
          child: AnimatedContainer(
            // Held at once; the release fades in 200 ms.
            duration: _held ? Duration.zero : const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _held ? KitColors.headerPressed : _clear,
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedBuilder(
              animation: _flash,
              builder: (BuildContext context, Widget? child) => DecoratedBox(
                key: const ValueKey<String>('profile-identity-flash'),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    KitColors.headerFlash,
                    _clear,
                    Curves.easeOut.transform(_flash.value),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: child,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: <Widget>[
                    _avatar(initials),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          still
                              ? nameText
                              : AnimatedBuilder(
                                  animation: _rise,
                                  builder: (BuildContext context, Widget? c) {
                                    final double t = Curves.easeOut.transform(
                                      _rise.value,
                                    );
                                    return Opacity(
                                      opacity: t,
                                      child: Transform.translate(
                                        offset: Offset(0, 4 * (1 - t)),
                                        child: c,
                                      ),
                                    );
                                  },
                                  child: nameText,
                                ),
                          if (hasName) ...<Widget>[
                            const SizedBox(height: 4),
                            _phoneText(phone, large),
                          ] else ...<Widget>[
                            const SizedBox(height: 8),
                            _setNamePill(l10n),
                            const SizedBox(height: 4),
                            _phoneText(phone, large),
                          ],
                        ],
                      ),
                    ),
                    if (hasName)
                      const Icon(
                        Icons.chevron_right,
                        size: 26,
                        color: Colors.white,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneText(String phone, bool large) {
    return Text(
      phone,
      key: const ValueKey<String>('profile-phone'),
      maxLines: large ? null : 1,
      overflow: large ? TextOverflow.visible : TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 15, height: 1.35, color: Colors.white),
    );
  }

  Widget _avatar(String? initials) {
    return Container(
      width: 70,
      height: 70,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: KitColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: initials == null
          ? const Icon(Icons.person, size: 36, color: KitColors.primaryDark)
          : Text(
              initials,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: KitColors.primaryDark,
              ),
            ),
    );
  }

  Widget _setNamePill(AppLocalizations l10n) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  l10n.profileSetName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: KitColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: KitColors.primaryDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeleton(AppLocalizations l10n) {
    return Semantics(
      key: const ValueKey<String>('profile-header-skeleton'),
      container: true,
      label: l10n.profileLoadingSpoken,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: <Widget>[
            const SkeletonBar(
              width: 70,
              height: 70,
              radius: 35,
              color: KitColors.headerSoft,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SkeletonBar(
                      width: box.maxWidth * 0.7,
                      height: 18,
                      color: KitColors.headerSoft,
                    ),
                    const SizedBox(height: 10),
                    SkeletonBar(
                      width: box.maxWidth * 0.48,
                      height: 14,
                      color: KitColors.headerSoft,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _failure(AppLocalizations l10n, Object? error) {
    return Padding(
      key: const ValueKey<String>('profile-header-failure'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: KitColors.headerSoft,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 70,
                height: 70,
                child: Icon(Icons.cloud_off, size: 30, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 4),
                Text(
                  l10n.profileLoadFailed,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error is NetworkFailure
                      ? l10n.profileLoadFailedOffline
                      : l10n.profileLoadFailedOther,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  key: const ValueKey<String>('profile-header-retry'),
                  onPressed: widget.onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: KitColors.primaryDark,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(l10n.retryButton),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
