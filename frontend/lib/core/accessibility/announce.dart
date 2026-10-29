import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';

/// Tells a screen reader [message] without moving focus (`DL-119`).
void announce(BuildContext context, String message) {
  SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    Directionality.of(context),
  );
}
