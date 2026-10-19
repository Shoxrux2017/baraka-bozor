import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/periodic_refresh.dart';
import '../application/customer_orders_controllers.dart';
import '../domain/customer_orders.dart';

/// The home's pointer to the question a Shopper is waiting on (drawing 27b).
/// It shows nothing while the question loads, when none waits, and when its
/// load failed; the order page is where the Customer answers.
class QuestionBanner extends ConsumerWidget {
  const QuestionBanner({super.key});

  static const Duration refreshEvery = Duration(seconds: 30);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PendingQuestion?> pending = ref.watch(
      pendingQuestionProvider,
    );
    final PendingQuestion? question = pending.hasError ? null : pending.value;

    return PeriodicRefresh(
      active: !pending.isLoading,
      interval: refreshEvery,
      onRefresh: () => ref.invalidate(pendingQuestionProvider),
      child: question == null
          ? const SizedBox.shrink()
          : _Card(question: question),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.question});

  final PendingQuestion question;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
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
                        l10n.questionBannerOrder(
                          '${question.orderNumber}',
                          TashkentTime.time(question.expiresAt),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: KitColors.ink2,
                        ),
                      ),
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
    );
  }
}
