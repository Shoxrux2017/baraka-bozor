import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/long_date.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/legal/legal_document_kind.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_scroll_indicator.dart';
import '../../../core/widgets/retry_strip.dart';
import '../application/legal_reader.dart';
import '../domain/legal.dart';
import 'legal_blocks.dart';
import 'legal_states.dart';

/// The terms of use or the privacy policy, read signed in or out: the
/// document in the interface language under a large title that hands over to
/// the bar as it scrolls away (`DL-136` (1)). While it loads there is a
/// skeleton under the title, a saved copy shows at once, and a failure is a
/// calm state in the middle or a strip over the copy (`DL-136` (4)).
class LegalScreen extends ConsumerStatefulWidget {
  const LegalScreen({required this.kind, super.key});

  final LegalDocumentKind kind;

  @override
  ConsumerState<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends ConsumerState<LegalScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _titleOpacity = ValueNotifier<double>(0);
  final ValueNotifier<double> _edgeOpacity = ValueNotifier<double>(0);

  /// The large title, and the top of the scroll content it is measured from.
  final GlobalKey _titleKey = GlobalKey();
  final GlobalKey _contentKey = GlobalKey();

  /// The text arriving over a skeleton fades in over 200 ms; at 1 it is simply
  /// there. Reduced motion does not play it.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  );
  late final Animation<double> _textOpacity = CurvedAnimation(
    parent: _fade,
    curve: Curves.easeOut,
  );

  /// Whether the face last built was the skeleton.
  bool _sawSkeleton = false;

  /// The state last spoken to a reader, so a rebuild does not repeat it.
  String? _spoken;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_follow);
    ref.listenManual<LegalReading>(legalReaderProvider(widget.kind), (
      LegalReading? before,
      LegalReading after,
    ) {
      final bool arrived = after.document != null && before?.document == null;
      if (arrived && _sawSkeleton && !MediaQuery.disableAnimationsOf(context)) {
        _fade.value = 0;
        unawaited(_fade.forward());
      }
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    _scroll
      ..removeListener(_follow)
      ..dispose();
    _titleOpacity.dispose();
    _edgeOpacity.dispose();
    super.dispose();
  }

  /// The bar's title takes over as the large title's bottom passes under it,
  /// over 22 px; the hairline arrives over the first 8 px of scroll.
  void _follow() {
    final double offset = _scroll.hasClients ? _scroll.offset : 0;
    _edgeOpacity.value = (offset / 8).clamp(0, 1);
    final RenderObject? title = _titleKey.currentContext?.findRenderObject();
    final RenderObject? content = _contentKey.currentContext
        ?.findRenderObject();
    if (title is RenderBox &&
        content is RenderBox &&
        title.attached &&
        content.attached) {
      final double bottom = title
          .localToGlobal(Offset(0, title.size.height), ancestor: content)
          .dy;
      _titleOpacity.value = ((offset - (bottom - 26)) / 22).clamp(0, 1);
    }
  }

  Widget _selectionMenu(BuildContext context, SelectableRegionState state) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: <ContextMenuButtonItem>[
        for (final ContextMenuButtonItem item in state.contextMenuButtonItems)
          switch (item.type) {
            ContextMenuButtonType.copy => item.copyWith(label: l10n.legalCopy),
            ContextMenuButtonType.selectAll => item.copyWith(
              label: l10n.legalSelectAll,
            ),
            _ => item,
          },
      ],
    );
  }

  /// Says [message] once for the state [key], after the frame that shows it.
  void _speak(String key, String? message) {
    if (key == _spoken) {
      return;
    }
    _spoken = key;
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted) {
          announce(context, message);
        }
      });
    }
  }

  void _retry() =>
      unawaited(ref.read(legalReaderProvider(widget.kind).notifier).retry());

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppPaths.bootstrap);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LegalReading reading = ref.watch(legalReaderProvider(widget.kind));
    final LegalDocument? document = reading.document;
    final ApiFailure? failure = reading.failure;
    final bool offline = failure is NetworkFailure;
    final String name = switch (widget.kind) {
      LegalDocumentKind.terms => l10n.legalTerms,
      LegalDocumentKind.privacy => l10n.legalPrivacy,
    };
    final bool skeleton =
        document == null && !reading.unpublished && failure == null;
    _sawSkeleton = skeleton;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        _follow();
      }
    });

    final Widget body;
    if (document != null || skeleton) {
      final String staleWords = offline
          ? l10n.legalStaleOffline
          : l10n.legalStaleFailed;
      final bool stale = document != null && failure != null;
      if (document == null) {
        _speak('skeleton', l10n.legalLoadingSpoken);
      } else if (!stale) {
        _speak('document', null);
      } else if (reading.loading) {
        _speak('busy', l10n.legalLoading);
      } else {
        _speak('strip:$offline', staleWords);
      }
      body = SelectionArea(
        contextMenuBuilder: _selectionMenu,
        child: ListScrollIndicator(
          fullExtent: (ScrollMetrics m) =>
              m.maxScrollExtent + m.viewportDimension,
          child: SingleChildScrollView(
            key: const ValueKey<String>('legal-scroll'),
            controller: _scroll,
            child: _Column(
              contentKey: _contentKey,
              titleKey: _titleKey,
              name: name,
              strip: !stale
                  ? null
                  : RetryStrip(
                      stripKey: const ValueKey<String>('legal-stale'),
                      retryKey: const ValueKey<String>('legal-stale-retry'),
                      icon: offline ? Icons.wifi_off : Icons.error_outline,
                      message: staleWords,
                      busyLabel: reading.loading ? l10n.legalLoading : null,
                      onRetry: _retry,
                    ),
              child: document == null
                  ? const LegalSkeleton(key: ValueKey<String>('legal-skeleton'))
                  : FadeTransition(
                      key: const ValueKey<String>('legal-text-fade'),
                      opacity: _textOpacity,
                      child: _Reading(document: document),
                    ),
            ),
          ),
        ),
      );
    } else if (reading.unpublished) {
      final String title = l10n.legalUnpublishedTitle;
      _speak('unpublished', title);
      body = LegalStatePanel(
        key: const ValueKey<String>('legal-unpublished'),
        controller: _scroll,
        icon: Icons.description_outlined,
        title: title,
        body: l10n.legalUnpublishedBody,
        button: LegalButton(
          key: const ValueKey<String>('legal-back'),
          label: l10n.back,
          outlined: true,
          onTap: _back,
        ),
      );
    } else {
      final String reason = offline
          ? l10n.legalFailedOffline
          : l10n.legalFailedOther;
      if (reading.loading) {
        _speak('busy', l10n.legalLoading);
      } else {
        _speak('failed:$offline', '${l10n.legalFailedTitle}. $reason');
      }
      body = LegalStatePanel(
        key: const ValueKey<String>('legal-failed'),
        controller: _scroll,
        icon: offline ? Icons.wifi_off : Icons.error_outline,
        title: l10n.legalFailedTitle,
        body: reason,
        button: LegalButton(
          key: const ValueKey<String>('legal-retry'),
          label: l10n.retryButton,
          busyLabel: reading.loading ? l10n.legalLoading : null,
          onTap: _retry,
        ),
      );
    }

    // Where a large title exists the bar's title takes over from it; with
    // none the bar's title is whole, and the hairline follows any scroll.
    final bool largeTitle = document != null || skeleton;
    return Scaffold(
      key: const ValueKey<String>('legal-screen'),
      backgroundColor: Colors.white,
      appBar: kitAppBar(
        title: name,
        titleOpacity: largeTitle ? _titleOpacity : null,
        edgeOpacity: _edgeOpacity,
      ),
      body: body,
    );
  }
}

/// The reading column: at most 600 wide, clear of the camera cutout, with the
/// large title, the [strip] of a copy that could not be refreshed, and the
/// [child] under them.
class _Column extends StatelessWidget {
  const _Column({
    required this.contentKey,
    required this.titleKey,
    required this.name,
    required this.strip,
    required this.child,
  });

  final GlobalKey contentKey;
  final GlobalKey titleKey;
  final String name;
  final Widget? strip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets inset = MediaQuery.paddingOf(context);
    final double titleSize =
        24 + 14 * (textScaleAt(MediaQuery.textScalerOf(context), 16) - 1);

    return Padding(
      padding: EdgeInsets.only(left: inset.left, right: inset.right),
      child: Align(
        key: contentKey,
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          key: const ValueKey<String>('legal-column'),
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 40 + inset.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Semantics(
                  key: titleKey,
                  header: true,
                  child: Text(
                    name,
                    key: const ValueKey<String>('legal-title'),
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: titleSize,
                      height: 1.2,
                      letterSpacing: -0.24,
                      fontWeight: FontWeight.w700,
                      color: KitColors.ink,
                    ),
                  ),
                ),
                if (strip != null) ...<Widget>[
                  const SizedBox(height: 12),
                  strip!,
                ],
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What a document shows under its title: the edition date, a note when the
/// document is not in the interface language, and the blocks.
class _Reading extends StatelessWidget {
  const _Reading({required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String shown = longDate(l10n, document.updatedAt);
    final bool otherLanguage =
        document.language !=
        AppLanguage.tryParse(Localizations.localeOf(context).languageCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          key: const ValueKey<String>('legal-date'),
          label: l10n.legalEditionSpoken(shown),
          excludeSemantics: true,
          child: Text(
            l10n.legalEdition(shown),
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: KitColors.muted,
            ),
          ),
        ),
        if (otherLanguage) ...<Widget>[
          const SizedBox(height: 12),
          _LanguageNote(language: document.language),
          const SizedBox(height: 16),
        ] else
          const SizedBox(height: 16),
        LegalBlocks(document.blocks),
      ],
    );
  }
}

/// «This document is only in Russian for now», under the date.
class _LanguageNote extends StatelessWidget {
  const _LanguageNote({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.page,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const ExcludeSemantics(
              child: Icon(Icons.info_outline, size: 18, color: KitColors.muted),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context).legalOnlyIn(language.code),
                key: const ValueKey<String>('legal-language-note'),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: KitColors.ink2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
