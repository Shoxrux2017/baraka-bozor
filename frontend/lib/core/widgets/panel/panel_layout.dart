import 'package:flutter/painting.dart';

/// The window widths at which the web panel's shell changes (`DL-100` (1)):
/// the icon rail from [panelRailWidth], the whole side menu from
/// [panelFullMenuWidth], a top bar with a menu button below the rail.
const double panelRailWidth = 1200;
const double panelFullMenuWidth = 1440;

/// The padding of a panel page in a window [windowWidth] wide: the roomier
/// one from the icon rail up, the tighter one below.
EdgeInsets panelPagePadding(double windowWidth) => windowWidth < panelRailWidth
    ? const EdgeInsets.fromLTRB(24, 20, 24, 24)
    : const EdgeInsets.fromLTRB(28, 26, 28, 28);
