import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';

/// Sheet 32б: the interface language, chosen from two rows. The choice is the
/// same language switch as everywhere: stored on the device and reported to
/// the server for push texts (`docs/07-architecture.md` section 27).
Future<void> showLanguageSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext sheet) => const _LanguageSheet(),
  );
}

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage? current = ref.watch(languageControllerProvider).value;

    return SingleChildScrollView(
      key: const ValueKey<String>('language-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: KitColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              l10n.profileLanguage,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _Option(
            optionKey: 'language-uz',
            label: l10n.languageUzbek,
            selected: current == AppLanguage.uz,
            language: AppLanguage.uz,
          ),
          _Option(
            optionKey: 'language-ru',
            label: l10n.languageRussian,
            selected: current == AppLanguage.ru,
            language: AppLanguage.ru,
          ),
        ],
      ),
    );
  }
}

class _Option extends ConsumerWidget {
  const _Option({
    required this.optionKey,
    required this.label,
    required this.selected,
    required this.language,
  });

  final String optionKey;
  final String label;
  final bool selected;
  final AppLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      key: ValueKey<String>(optionKey),
      onTap: () {
        ref.read(languageControllerProvider.notifier).select(language);
        Navigator.of(context).pop();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: KitColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 24,
              color: selected ? KitColors.primary : KitColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}
