import 'package:flutter/material.dart';

import '../localization/failure_text.dart';
import '../localization/generated/app_localizations.dart';
import '../network/api_failure.dart';

/// The text of a failure under a form, in the error colour and announced
/// to assistive technology as an alert. Renders nothing when there is no
/// failure or nothing to say about it.
class FailureMessage extends StatelessWidget {
  const FailureMessage(this.failure, {super.key});

  final ApiFailure? failure;

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
