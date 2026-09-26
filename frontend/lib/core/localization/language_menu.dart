import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'app_language.dart';
import 'generated/app_localizations.dart';

/// The in-app language switch of `docs/07-architecture.md` section 27, as
/// an app-bar action. Each language is named in itself, so a person who
/// cannot read the current one still finds their own.
class LanguageMenuButton extends ConsumerWidget {
  const LanguageMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage? current = ref.watch(languageControllerProvider).value;

    return PopupMenuButton<AppLanguage>(
      icon: const Icon(Icons.language),
      tooltip: l10n.languageLabel,
      initialValue: current,
      onSelected: (AppLanguage language) =>
          ref.read(languageControllerProvider.notifier).select(language),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<AppLanguage>>[
        CheckedPopupMenuItem<AppLanguage>(
          value: AppLanguage.uz,
          checked: current == AppLanguage.uz,
          child: Text(l10n.languageUzbek),
        ),
        CheckedPopupMenuItem<AppLanguage>(
          value: AppLanguage.ru,
          checked: current == AppLanguage.ru,
          child: Text(l10n.languageRussian),
        ),
      ],
    );
  }
}
