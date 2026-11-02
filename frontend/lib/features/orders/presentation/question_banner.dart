import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/platform/clock.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/deadline_chip.dart';
import '../../../core/widgets/fold.dart';
import '../../../core/widgets/periodic_refresh.dart';
import '../application/customer_orders_controllers.dart';
import '../domain/customer_orders.dart';

/// The home's pointer to the question a Shopper is waiting on (drawing 27b):
/// the one expiring first among those still open. It unfolds with a light
/// buzz and an announcement when one arrives after an answer without any, and
/// folds with an announcement at its expiry; an answered one folds silently.
/// The order page is where the Customer answers (`DL-125`).
class QuestionBanner extends ConsumerStatefulWidget {
  const QuestionBanner({super.key});

  static const Duration refreshEvery = Duration(seconds: 30);

  @override
  ConsumerState<QuestionBanner> createState() => _QuestionBannerState();
}

class _QuestionBannerState extends ConsumerState<QuestionBanner> {
  /// The question the banner shows, kept while it folds.
  PendingQuestion? _last;

  /// Whether the pending questions had loaded when the last frame was built.
  bool _loadedBefore = false;

  /// Whether the banner in the tree unfolds on its first frame.
  bool _appear = false;

  /// A timer stops while the device sleeps: coming back to the app drops the
  /// questions that expired meanwhile (`DL-125`).
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => ref.invalidate(openQuestionsProvider),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onOpenChanged(
    List<PendingQuestion>? before,
    List<PendingQuestion> after,
  ) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime now = ref.read(clockProvider)();
    final PendingQuestion? was = before?.firstOrNull;
    final PendingQuestion? is_ = after.firstOrNull;
    if (was == null && is_ != null && _loadedBefore) {
      HapticFeedback.lightImpact();
      announce(
        context,
        l10n.questionArrived(
          '${is_.orderNumber}',
          l10n.deadlineLeftSpoken(minutesLeft(is_.expiresAt, now)),
        ),
      );
    } else if (was != null &&
        (is_ == null || is_.approvalId != was.approvalId) &&
        !after.any((PendingQuestion q) => q.approvalId == was.approvalId) &&
        !was.expiresAt.isAfter(now)) {
      announce(context, l10n.questionExpired);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<PendingQuestion>>(openQuestionsProvider, _onOpenChanged);
    final AsyncValue<List<PendingQuestion>> pending = ref.watch(
      pendingQuestionsProvider,
    );
    final PendingQuestion? question = ref
        .watch(openQuestionsProvider)
        .firstOrNull;
    if (question != null) {
      if (_last == null) {
        _appear = _loadedBefore;
      }
      _last = question;
    }
    _loadedBefore = pending.hasValue;
    final PendingQuestion? shown = _last;

    return PeriodicRefresh(
      active: !pending.isLoading,
      interval: QuestionBanner.refreshEvery,
      onRefresh: () => ref.invalidate(pendingQuestionsProvider),
      child: shown == null
          ? const SizedBox.shrink()
          : Fold(
              shown: question != null,
              appear: _appear,
              onFolded: () => setState(() => _last = null),
              child: _Card(question: shown),
            ),
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.question});

  final PendingQuestion question;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int minutes = minutesLeft(
      question.expiresAt,
      ref.watch(clockProvider)(),
    );
    void open() => context.push<void>(AppPaths.customerOrder(question.orderId));
    // A large text leaves the texts no room beside the button.
    final bool stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final Widget answer = FilledButton(
      key: const ValueKey<String>('question-banner-answer'),
      style: FilledButton.styleFrom(
        backgroundColor: KitColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: open,
      child: Text(
        l10n.questionAnswer,
        maxLines: 1,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: l10n.questionSpoken(
          '${question.orderNumber}',
          l10n.deadlineLeftSpoken(minutes),
        ),
        onTap: open,
        child: Material(
          key: const ValueKey<String>('question-banner'),
          color: KitColors.warningWash,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      color: KitColors.warning,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 36,
                      child: Icon(Icons.help, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.questionBannerTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: KitColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.questionBannerUntil(
                            '${question.orderNumber}',
                            TashkentTime.time(question.expiresAt),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: KitColors.ink2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DeadlineChip(deadline: question.expiresAt),
                        if (stacked) ...<Widget>[
                          const SizedBox(height: 8),
                          answer,
                        ],
                      ],
                    ),
                  ),
                  if (!stacked) ...<Widget>[const SizedBox(width: 8), answer],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
