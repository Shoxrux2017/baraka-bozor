import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';

/// The calm mark of a state that has nothing to show (`DL-136`): a 64 px
/// `chip` circle holding a 30 px `ink2` icon. It says nothing to a reader; the
/// words beside it do.
class QuietIcon extends StatelessWidget {
  const QuietIcon({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 64,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: KitColors.chip,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 30, color: KitColors.ink2),
        ),
      ),
    );
  }
}
