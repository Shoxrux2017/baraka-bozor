import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/generated/app_localizations.dart';
import '../routing/app_paths.dart';

import '../theme/kit_colors.dart';

/// The kit screens' app bar: a centred title on plain white, without Material
/// 3's tint and without a colour change when the body scrolls under it. With
/// [search] it carries the search icon of a list's header, which opens the
/// search screen (`DL-83`); other [actions] take its place on a screen that
/// has its own.
AppBar kitAppBar({
  required String title,
  bool automaticallyImplyLeading = true,
  bool search = false,
  List<Widget>? actions,
}) {
  return AppBar(
    automaticallyImplyLeading: automaticallyImplyLeading,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    centerTitle: true,
    actions: search ? const <Widget>[_SearchAction()] : actions,
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: KitColors.ink,
      ),
    ),
  );
}

class _SearchAction extends StatelessWidget {
  const _SearchAction();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey<String>('open-search'),
      icon: const Icon(Icons.search, size: 26, color: KitColors.ink),
      tooltip: AppLocalizations.of(context).openSearch,
      onPressed: () => context.push<void>(AppPaths.customerSearch),
    );
  }
}
