import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/localization/generated/app_localizations.dart';
import 'auth_scaffold.dart';

/// A stored session the server could not confirm: the tokens are kept and
/// the person tries again (`docs/DECISIONS.md` DL-13, point 4).
class UnreachableScreen extends ConsumerWidget {
  const UnreachableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool retrying = ref.watch(sessionControllerProvider).isLoading;

    return AuthScaffold(
      title: l10n.sessionUnreachableTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.sessionUnreachableBody),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey<String>('retry-button'),
            onPressed: retrying
                ? null
                : () => ref.read(sessionControllerProvider.notifier).retry(),
            child: Text(l10n.retryButton),
          ),
        ],
      ),
    );
  }
}
