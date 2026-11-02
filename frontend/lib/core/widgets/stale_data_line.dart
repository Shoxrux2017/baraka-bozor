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
    super.key,
  });

  final ApiFailure failure;
  final DateTime? shownAt;
  final VoidCallback onRetry;

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
          child: Row(
            children: <Widget>[
              const ExcludeSemantics(
                child: Icon(Icons.cloud_off, size: 18, color: KitColors.muted),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  label: spoken,
                  excludeSemantics: true,
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 12, color: KitColors.ink2),
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey<String>('stale-retry'),
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: KitColors.primaryDark,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(
                  time == null ? l10n.retryButton : l10n.staleRefresh,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
