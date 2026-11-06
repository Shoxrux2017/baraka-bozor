import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/accessibility/announce.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';

/// Sheet 32б: the interface language, chosen from two rows. The choice is the
/// same language switch as everywhere: stored on the device and reported to
/// the server for push texts (`docs/07-architecture.md` section 27). A choice
/// is ticked with a pop, buzzed and announced, and the sheet closes 0.3 s
/// later so the tick can be seen (`DL-135`).
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

class _LanguageSheet extends ConsumerStatefulWidget {
  const _LanguageSheet();

  @override
  ConsumerState<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends ConsumerState<_LanguageSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  /// The check pops 1 → 1.35 → 0.94 → 1.
  late final Animation<double> _scale = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      _step(1, 1.35, 40),
      _step(1.35, 0.94, 35),
      _step(0.94, 1, 25),
    ],
  ).animate(_pop);

  static TweenSequenceItem<double> _step(double from, double to, double w) =>
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: from,
          end: to,
        ).chain(CurveTween(curve: const Cubic(0.2, 0.8, 0.2, 1))),
        weight: w,
      );

  Timer? _close;

  /// The language just tapped; taps are ignored from then until the sheet
  /// closes.
  AppLanguage? _picked;

  @override
  void dispose() {
    _close?.cancel();
    _pop.dispose();
    super.dispose();
  }

  void _choose(AppLanguage language) {
    if (_picked != null) {
      return;
    }
    final AppLanguage? current = ref.read(languageControllerProvider).value;
    setState(() => _picked = language);
    if (language != current) {
      ref.read(languageControllerProvider.notifier).select(language);
      unawaited(HapticFeedback.selectionClick());
      final AppLocalizations words = lookupAppLocalizations(language.locale);
      announce(
        context,
        words.languageChosenSpoken(switch (language) {
          AppLanguage.uz => words.languageUzbek,
          AppLanguage.ru => words.languageRussian,
        }),
      );
      if (!MediaQuery.disableAnimationsOf(context)) {
        unawaited(_pop.forward(from: 0));
      }
    }
    _close = Timer(const Duration(milliseconds: 300), () {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage? current =
        _picked ?? ref.watch(languageControllerProvider).value;

    return SingleChildScrollView(
      key: const ValueKey<String>('language-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: KitColors.fieldEdge,
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
            scale: _scale,
            line: true,
            onTap: () => _choose(AppLanguage.uz),
          ),
          _Option(
            optionKey: 'language-ru',
            label: l10n.languageRussian,
            selected: current == AppLanguage.ru,
            scale: _scale,
            line: false,
            onTap: () => _choose(AppLanguage.ru),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.optionKey,
    required this.label,
    required this.selected,
    required this.scale,
    required this.line,
    required this.onTap,
  });

  final String optionKey;
  final String label;
  final bool selected;
  final Animation<double> scale;
  final bool line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey<String>(optionKey),
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          decoration: BoxDecoration(
            border: line
                ? const Border(bottom: BorderSide(color: KitColors.line))
                : null,
          ),
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
              if (selected)
                ScaleTransition(
                  scale: scale,
                  child: const Icon(
                    Icons.check,
                    key: ValueKey<String>('language-check'),
                    size: 24,
                    color: KitColors.primary,
                  ),
                )
              else
                const SizedBox(width: 24),
            ],
          ),
        ),
      ),
    );
  }
}
