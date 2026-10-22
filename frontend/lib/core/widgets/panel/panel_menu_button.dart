import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';
import '../kit/kit_buttons.dart';

/// One choice of a [PanelMenuButton].
typedef PanelMenuItem<T> = ({T value, String label});

/// The look of a panel filter button: [kitOutlined] 40 high with 13 / w600
/// text; [active] washes it green with a 1.5 outline and dark text.
ButtonStyle panelFilterStyle({required bool active}) {
  return kitOutlined(
    foreground: active ? KitColors.primaryDark : KitColors.ink,
    height: 40,
  ).copyWith(
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const WidgetStatePropertyAll<TextStyle>(
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    padding: const WidgetStatePropertyAll<EdgeInsets>(
      EdgeInsets.symmetric(horizontal: 12),
    ),
    backgroundColor: WidgetStatePropertyAll<Color>(
      active ? KitColors.primaryWash : Colors.white,
    ),
    side: WidgetStatePropertyAll<BorderSide>(
      active
          ? const BorderSide(color: KitColors.primary, width: 1.5)
          : const BorderSide(color: KitColors.line),
    ),
  );
}

/// The panel's filter button: 40 high, its [label] and a chevron, opening a
/// menu of [items] (each keyed `<buttonKey>-<index>`). An [active] button —
/// a filter is on — is drawn green: a wash, a 1.5 outline and dark text.
class PanelMenuButton<T> extends StatelessWidget {
  const PanelMenuButton({
    required this.buttonKey,
    required this.label,
    required this.active,
    required this.items,
    required this.onSelected,
    super.key,
  });

  final String buttonKey;
  final String label;
  final bool active;
  final List<PanelMenuItem<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(Colors.white),
        surfaceTintColor: WidgetStatePropertyAll<Color>(Colors.transparent),
      ),
      menuChildren: <Widget>[
        for (int index = 0; index < items.length; index++)
          MenuItemButton(
            key: ValueKey<String>('$buttonKey-$index'),
            onPressed: () => onSelected(items[index].value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                items[index].label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
      builder: (BuildContext context, MenuController controller, Widget? _) {
        return OutlinedButton(
          key: ValueKey<String>(buttonKey),
          style: panelFilterStyle(active: active),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 18),
            ],
          ),
        );
      },
    );
  }
}
