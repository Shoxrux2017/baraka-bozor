import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';

/// The widest a kit dialog gets; a narrower window gives it its width less 32.
const double kitDialogWidth = 480;

/// A centred window of the kit for the panel: a white card of radius 20 over
/// a dim scrim, its [title] with a x at the right, an optional muted
/// [subtitle], then the [builder] body, which scrolls above the keyboard.
/// The x only asks the route to pop, so a body wrapped in
/// `PopScope(canPop: false)` (an action that runs) holds through the x, the
/// scrim and back alike.
///
/// The root is keyed `ValueKey(dialogKey)` and the x
/// `ValueKey('$dialogKey-close')`.
Future<T?> showKitDialog<T>({
  required BuildContext context,
  required String dialogKey,
  required String title,
  String? subtitle,
  required WidgetBuilder builder,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: const Color(0x61151D16),
    builder: (BuildContext dialog) => _KitDialog(
      dialogKey: dialogKey,
      title: title,
      subtitle: subtitle,
      builder: builder,
    ),
  );
}

class _KitDialog extends StatelessWidget {
  const _KitDialog({
    required this.dialogKey,
    required this.title,
    required this.subtitle,
    required this.builder,
  });

  final String dialogKey;
  final String title;
  final String? subtitle;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final String? subtitle = this.subtitle;

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(
            kitDialogWidth,
            MediaQuery.sizeOf(context).width - 32,
          ),
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
                  builder(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
