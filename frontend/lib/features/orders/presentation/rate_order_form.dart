import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/order_dates.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/platform/clock.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/fold.dart';
import '../../../core/widgets/product_image.dart';
import '../application/rate_draft.dart';
import '../domain/customer_orders.dart';
import 'kit_choice_chip.dart';
import 'rating_stars.dart';

/// The scrolling part of the rating screen (`DL-134`): the order named and
/// pictured, the stars with their word, the reasons at 1 to 3 stars, the
/// comment, the Operator's note. It holds no state beyond the word's entrance;
/// [draft] is the screen's and every change goes out through [onDraft] or
/// [onStars]. While [frozen] (a send is on its way) the whole form fades and
/// answers nothing; while [locked] (a lost answer is to be resent as it was)
/// the stars, reasons and field fade and answer nothing.
class RateOrderForm extends StatelessWidget {
  const RateOrderForm({
    required this.order,
    required this.draft,
    required this.onDraft,
    required this.onStars,
    required this.comment,
    required this.frozen,
    required this.locked,
    super.key,
  });

  final CustomerOrder order;
  final RateDraft draft;
  final ValueChanged<RateDraft> onDraft;
  final void Function(int stars, RatingInput how) onStars;
  final TextEditingController comment;
  final bool frozen;
  final bool locked;

  static String wordOf(AppLocalizations l10n, int? stars) => switch (stars) {
    1 => l10n.rateStar1,
    2 => l10n.rateStar2,
    3 => l10n.rateStar3,
    4 => l10n.rateStar4,
    5 => l10n.rateStar5,
    _ => '',
  };

  static String exampleOf(AppLocalizations l10n, RateExample example) =>
      switch (example) {
        RateExample.good => l10n.rateCommentHintGood,
        RateExample.bad => l10n.rateCommentHintBad,
        RateExample.notFresh => l10n.rateExampleNotFresh,
        RateExample.wrongWeight => l10n.rateExampleWrongWeight,
        RateExample.late => l10n.rateExampleLate,
        RateExample.rude => l10n.rateExampleRude,
        RateExample.many => l10n.rateExampleMany,
      };

  void _tapReason(
    BuildContext context,
    AppLocalizations l10n,
    RatingReason reason,
  ) {
    final bool on = !draft.reasons.contains(reason);
    onDraft(
      draft.copyWith(
        reasons: on
            ? <RatingReason>{...draft.reasons, reason}
            : (<RatingReason>{...draft.reasons}..remove(reason)),
      ),
    );
    final String label = OrderLabels.ratingReason(l10n, reason);
    announce(
      context,
      on ? l10n.cancelChipSpokenOn(label) : l10n.cancelChipSpokenOff(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool low = isLowRating(draft.stars);
    final bool editable = !frozen && !locked;
    final bool over = draft.tooLong;
    final int left = rateCommentMax - draft.length;
    final Duration fade = _duration(context, 200);

    return AnimatedOpacity(
      opacity: frozen ? 0.55 : 1,
      duration: fade,
      curve: Curves.easeOut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _RateHeader(
            key: const ValueKey<String>('rate-header'),
            order: order,
            low: low,
          ),
          AnimatedOpacity(
            opacity: locked ? 0.55 : 1,
            duration: fade,
            curve: Curves.easeOut,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 16),
                Center(
                  child: RatingStars(
                    key: const ValueKey<String>('rate-stars'),
                    value: draft.stars,
                    adjustable: true,
                    enabled: editable,
                    onChanged: onStars,
                  ),
                ),
                const SizedBox(height: 4),
                _Word(text: wordOf(l10n, draft.stars)),
                _Folded(
                  key: const ValueKey<String>('rate-reasons'),
                  shown: low,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const SizedBox(height: 20),
                      Semantics(
                        header: true,
                        label:
                            '${l10n.rateWhatWrong} ${l10n.rateWhatWrongMany}',
                        excludeSemantics: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              l10n.rateWhatWrong,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                                color: KitColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.rateWhatWrongMany,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: KitColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            for (final RatingReason reason
                                in RatingReason.values)
                              KitChoiceChip(
                                key: ValueKey<String>(
                                  'rate-reason-${reason.code}',
                                ),
                                label: OrderLabels.ratingReason(l10n, reason),
                                chosen: draft.reasons.contains(reason),
                                enabled: editable,
                                ground: KitColors.field,
                                onTap: () {
                                  if (editable) {
                                    _tapReason(context, l10n, reason);
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ExcludeSemantics(
                  child: Text(
                    l10n.rateComment,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: KitColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  key: const ValueKey<String>('rate-field'),
                  decoration: BoxDecoration(
                    color: KitColors.field,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: over ? KitColors.danger : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Semantics(
                    label: l10n.rateCommentSpoken,
                    child: TextField(
                      key: const ValueKey<String>('rate-comment'),
                      controller: comment,
                      readOnly: !editable,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (String text) =>
                          onDraft(draft.copyWith(comment: text)),
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: KitColors.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: exampleOf(l10n, draft.example),
                        hintStyle: const TextStyle(color: KitColors.muted),
                        filled: false,
                        counterText: '',
                        constraints: const BoxConstraints(minHeight: 50),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                if (draft.length >= rateCounterFrom)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        left >= 0
                            ? l10n.cancelLeft(left)
                            : l10n.rateOver(-left),
                        key: const ValueKey<String>('rate-counter'),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: over ? FontWeight.w600 : FontWeight.w400,
                          color: over ? KitColors.danger : KitColors.muted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (low) ...<Widget>[
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: KitColors.primaryWash,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.support_agent,
                      size: 22,
                      color: KitColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.rateOperatorWillCall,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: KitColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Duration _duration(BuildContext context, int milliseconds) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

/// [child] folded away while [shown] is false: it takes no room, no touch, no
/// focus and no place in a reader's walk.
class _Folded extends StatelessWidget {
  const _Folded({required this.shown, required this.child, super.key});

  final bool shown;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Fold(
      shown: shown,
      child: IgnorePointer(
        ignoring: !shown,
        child: ExcludeFocus(
          excluding: !shown,
          child: ExcludeSemantics(excluding: !shown, child: child),
        ),
      ),
    );
  }
}

/// The order named: up to three pictures with «+N» for the rest, the
/// question, what was bought and when it came, and the hint. The pictures and
/// the hint fold away while the reasons are asked ([low]); a reader hears the
/// header as one sentence.
class _RateHeader extends ConsumerWidget {
  const _RateHeader({required this.order, required this.low, super.key});

  final CustomerOrder order;
  final bool low;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final DateTime now = ref.watch(clockProvider)();
    final List<CustomerOrderLine> lines = order.openLines;
    final String names = _names(l10n, language, lines);
    final DateTime? completedAt = order.completedAt;
    final String? when = completedAt == null
        ? null
        : orderAtLower(l10n, completedAt, now);
    final String? sub = names.isEmpty
        ? null
        : when == null
        ? names
        : l10n.rateHeaderSub(names, when);
    final String spoken = when == null
        ? <String>[
            l10n.rateBlockTitle,
            names,
          ].where((String part) => part.isNotEmpty).join(' ')
        : l10n.rateHeaderSpoken(order.orderNumber, when, names);

    return Semantics(
      container: true,
      header: true,
      label: spoken,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (lines.isNotEmpty)
            _Folded(
              key: const ValueKey<String>('rate-photos'),
              shown: !low,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(child: _Photos(lines: lines)),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            l10n.rateBlockTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: KitColors.ink,
            ),
          ),
          if (sub != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: KitColors.ink2,
              ),
            ),
          ],
          _Folded(
            key: const ValueKey<String>('rate-hint'),
            shown: !low,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.rateHint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: KitColors.muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// What was bought: the first line's name, the first two, or the first two
  /// and how many more there are.
  static String _names(
    AppLocalizations l10n,
    AppLanguage language,
    List<CustomerOrderLine> lines,
  ) {
    if (lines.isEmpty) {
      return '';
    }
    final String first = lines[0].name(language);
    if (lines.length == 1) {
      return first;
    }
    final String second = lines[1].name(language);
    return lines.length == 2
        ? l10n.rateNamesTwo(first, second)
        : l10n.rateNamesMore(first, second, lines.length - 2);
  }
}

/// Up to three product pictures, each after the first lying 10 over its
/// neighbour, and «+N» for the lines beyond three.
class _Photos extends StatelessWidget {
  const _Photos({required this.lines});

  final List<CustomerOrderLine> lines;

  static const double _tile = 56;
  static const double _step = _tile - 10;

  @override
  Widget build(BuildContext context) {
    final bool more = lines.length > 3;
    final int count = more ? 4 : lines.length;
    return SizedBox(
      width: _tile + (count - 1) * _step,
      height: _tile,
      child: Stack(
        children: <Widget>[
          for (int i = 0; i < count; i++)
            Positioned(
              left: i * _step,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: KitColors.page,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Colors.white, spreadRadius: 3),
                  ],
                ),
                child: SizedBox.square(
                  dimension: _tile,
                  child: Center(
                    child: i < 3
                        ? ProductImage(url: lines[i].imageUrl, size: 40)
                        : Text(
                            '+${lines.length - 3}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: KitColors.ink2,
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The word of the stars: it keeps one line's height when empty, and rises 4 px
/// with a fade in 200 ms at each change (a 150 ms fade with reduced motion).
class _Word extends StatefulWidget {
  const _Word({required this.text});

  final String text;

  @override
  State<_Word> createState() => _WordState();
}

class _WordState extends State<_Word> with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    value: 1,
  );

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_Word oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text && widget.text.isNotEmpty) {
      _run.duration = Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 150 : 200,
      );
      unawaited(_run.forward(from: 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final double line = MediaQuery.textScalerOf(context).scale(16) * 1.3;
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: line),
        child: AnimatedBuilder(
          animation: _run,
          builder: (BuildContext context, Widget? child) {
            final double t = Curves.easeOut.transform(_run.value);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, reduced ? 0 : (1 - t) * 4),
                child: child,
              ),
            );
          },
          child: Text(
            widget.text,
            key: const ValueKey<String>('rate-word'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: KitColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
