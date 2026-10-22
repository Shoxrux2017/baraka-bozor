import 'package:flutter/material.dart';

import '../localization/failure_text.dart';
import '../localization/generated/app_localizations.dart';
import '../network/api_failure.dart';
import '../theme/kit_colors.dart';

/// The text of a failure under a form, in the error colour and announced
/// to assistive technology as an alert. Renders nothing when there is no
/// failure or nothing to say about it. [boxed] puts it on a red wash with an
/// error icon, as the panel's sign-in card shows it.
class FailureMessage extends StatelessWidget {
  const FailureMessage(this.failure, {this.boxed = false, super.key});

  final ApiFailure? failure;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final ApiFailure? failure = this.failure;
    if (failure == null) {
      return const SizedBox.shrink();
    }

    final String? text = failureText(AppLocalizations.of(context), failure);
    if (text == null) {
      return const SizedBox.shrink();
    }

    if (boxed) {
      return Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: KitColors.dangerWash,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.error, size: 18, color: KitColors.danger),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    key: const ValueKey<String>('failure-message'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: KitColors.dangerDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          text,
          key: const ValueKey<String>('failure-message'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}
