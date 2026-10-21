import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';

/// A bottom sheet of the kit for the staff screens: white, round on top, a
/// handle, a title row with a x and a rule, then the [builder] body. The
/// sheet is never dragged closed (`enableDrag: false`), and the x only asks
/// the route to pop, so a body wrapped in `PopScope(canPop: false)` (a sheet
/// whose request runs) holds through the x, back and the scrim alike.
///
/// The root is keyed `ValueKey(sheetKey)` and the x `ValueKey('$sheetKey-close')`.
/// The body scrolls above the keyboard.
Future<T?> showKitSheet<T>(
  BuildContext context, {
  required String title,
  required String sheetKey,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext sheet) =>
        _KitSheet(title: title, sheetKey: sheetKey, builder: builder),
  );
}

class _KitSheet extends StatelessWidget {
  const _KitSheet({
    required this.title,
    required this.sheetKey,
    required this.builder,
  });

  final String title;
  final String sheetKey;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: ValueKey<String>(sheetKey),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: KitColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: KitColors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  label: MaterialLocalizations.of(context).closeButtonLabel,
                  child: InkResponse(
                    key: ValueKey<String>('$sheetKey-close'),
                    onTap: () => Navigator.of(context).maybePop(),
                    radius: 24,
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: KitColors.ink, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: KitColors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: KitColors.line),
          builder(context),
        ],
      ),
    );
  }
}
