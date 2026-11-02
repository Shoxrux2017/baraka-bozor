import 'package:flutter/material.dart';

import '../formatting/tashkent_time.dart';
import '../localization/generated/app_localizations.dart';
import '../network/api_failure.dart';
import '../theme/kit_colors.dart';

/// The line over data that could not be refreshed (`DL-125`): why, when the
/// data on screen is from, and a button to refresh. Without [shownAt] nothing
/// was loaded yet and the button reads «Повторить». It fades in over 200 ms
/// (at once with reduced motion) and is one live region for a screen reader.
/// The caller places it and gives it its margin.
class StaleDataLine extends StatelessWidget {
  const StaleDataLine({
    required this.failure,
    required this.shownAt,
    required this.onRetry,
    this.busy = false,
    super.key,
  });

  final ApiFailure failure;
  final DateTime? shownAt;
  final VoidCallback onRetry;

  /// A load is on its way: the button shows a small spinner in place of its
  /// word and takes no tap, so a second tap starts no second request.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime? at = shownAt;
    final String reason = failure is NetworkFailure
        ? l10n.staleOffline
        : l10n.staleFailed;
    final String? time = at == null ? null : TashkentTime.time(at);
    final String text = time == null
        ? reason
        : '$reason · ${l10n.staleShownAt(time)}';
    final String spoken = time == null
        ? reason
        : l10n.staleSpoken(reason, time);
    // A large text leaves the words no room beside the button: it goes under
    // them.
    final bool stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    const Widget icon = ExcludeSemantics(
      child: Padding(
        padding: EdgeInsets.only(right: 8),
        child: Icon(Icons.cloud_off, size: 18, color: KitColors.muted),
      ),
    );
    final Widget message = Expanded(
      child: Semantics(
        liveRegion: true,
        label: spoken,
        excludeSemantics: true,
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: KitColors.ink2),
        ),
      ),
    );
    final Widget button = TextButton(
      key: const ValueKey<String>('stale-retry'),
      onPressed: busy ? null : onRetry,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: KitColors.primaryDark,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: KitColors.primary,
              ),
            )
          : Text(time == null ? l10n.retryButton : l10n.staleRefresh),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      builder: (BuildContext context, double opacity, Widget? child) =>
          Opacity(opacity: opacity, child: child),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KitColors.field,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(children: <Widget>[icon, message]),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: button,
                    ),
                  ],
                )
              : Row(children: <Widget>[icon, message, button]),
        ),
      ),
    );
  }
}
