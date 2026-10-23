import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../localization/generated/app_localizations.dart';
import '../../theme/kit_colors.dart';
import 'kit_buttons.dart';

/// The widest a kit dialog gets; a narrower window gives it its width less 32.
const double kitDialogWidth = 480;

/// A centred window of the kit for the panel: a white card of radius 20 over
/// a dim scrim, its [title] with a x at the right, an optional muted
/// [subtitle], then the [builder] body, which scrolls above the keyboard.
/// The x only asks the route to pop, so a body wrapped in
/// `PopScope(canPop: false)` (an action that runs) holds through the x, the
/// scrim and back alike.
///
/// A wider window passes [maxWidth]; it is never wider than the screen less
/// 32. With [barrierDismissible] false a tap outside does not close it.
///
/// The root is keyed `ValueKey(dialogKey)` and the x
/// `ValueKey('$dialogKey-close')`.
Future<T?> showKitDialog<T>({
  required BuildContext context,
  required String dialogKey,
  required String title,
  String? subtitle,
  Widget? badge,
  required WidgetBuilder builder,
  double maxWidth = kitDialogWidth,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: const Color(0x61151D16),
    builder: (BuildContext dialog) => KitDialogFrame(
      dialogKey: dialogKey,
      title: title,
      subtitle: subtitle,
      badge: badge,
      maxWidth: maxWidth,
      child: Builder(builder: builder),
    ),
  );
}

/// The body of a kit dialog: the card with its [title], an optional muted
/// [subtitle], an optional [badge] above the title and the [child]. A frame
/// that is not [closable] leaves out the x.
class KitDialogFrame extends StatelessWidget {
  const KitDialogFrame({
    required this.dialogKey,
    required this.title,
    this.subtitle,
    this.badge,
    this.closable = true,
    this.maxWidth = kitDialogWidth,
    required this.child,
    super.key,
  });

  final String dialogKey;
  final String title;
  final String? subtitle;
  final Widget? badge;
  final bool closable;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final String? subtitle = this.subtitle;
    final Widget? badge = this.badge;

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(maxWidth, MediaQuery.sizeOf(context).width - 32),
        ),
        child: DecoratedBox(
          key: ValueKey<String>(dialogKey),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 60,
                offset: Offset(0, 24),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (badge != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: badge,
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Semantics(
                            header: true,
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: KitColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (closable)
                        Semantics(
                          button: true,
                          label: MaterialLocalizations.of(context)
                              .closeButtonLabel,
                          child: InkResponse(
                            key: ValueKey<String>('$dialogKey-close'),
                            onTap: () => Navigator.of(context).maybePop(),
                            radius: 20,
                            child: Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: KitColors.field,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: KitColors.ink,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 40),
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: KitColors.muted,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 52 circle with an [icon] 26 big, on the green wash or — [danger] — the
/// red one; it stands above a window's title.
class KitDialogBadge extends StatelessWidget {
  const KitDialogBadge(this.icon, {this.danger = false, super.key});

  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: danger ? KitColors.dangerWash : KitColors.primaryWash,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 26,
        color: danger ? KitColors.dangerDark : KitColors.primaryDark,
      ),
    );
  }
}

/// The two buttons a window ends with: "Cancel" outlined (keyed [cancelKey])
/// and the confirming button, a red one when the action [destructive]ly
/// cancels or removes. While [busy] both are disabled.
Widget kitDialogButtons({
  required BuildContext context,
  required bool busy,
  required Key confirmKey,
  required String confirm,
  required VoidCallback submit,
  IconData? confirmIcon,
  bool destructive = false,
  Key cancelKey = const ValueKey<String>('action-cancel'),
}) {
  final ButtonStyle style = kitFilled(
    color: destructive ? KitColors.danger : KitColors.primary,
    height: 48,
  );
  final VoidCallback? onPressed = busy ? null : submit;

  return KitActionPair(
    secondary: OutlinedButton(
      key: cancelKey,
      style: kitOutlined(height: 48),
      onPressed: busy ? null : () => Navigator.of(context).pop(),
      child: Text(AppLocalizations.of(context).cancelButton),
    ),
    primary: confirmIcon == null
        ? FilledButton(
            key: confirmKey,
            style: style,
            onPressed: onPressed,
            child: Text(confirm),
          )
        : FilledButton.icon(
            key: confirmKey,
            style: style,
            onPressed: onPressed,
            icon: Icon(confirmIcon, size: 20),
            label: Text(confirm),
          ),
  );
}
