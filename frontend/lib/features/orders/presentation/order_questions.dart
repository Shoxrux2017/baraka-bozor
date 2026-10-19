import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/idempotency_key.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/state/mutation_state.dart';
import '../application/customer_orders_controllers.dart';
import '../domain/customer_orders.dart';

/// A question about a line in the Customer's words, with its answers
/// (`docs/09` section 23). After an answer that did not say what it did, it
/// offers only to send the same decision again, under the same key.
class OrderQuestionCard extends ConsumerWidget {
  const OrderQuestionCard({
    required this.orderId,
    required this.line,
    required this.question,
    required this.deciding,
    required this.language,
    super.key,
  });

  final String orderId;
  final CustomerOrderLine line;
  final CustomerQuestion question;
  final MutationState deciding;
  final AppLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String unit = CatalogLabels.unit(l10n, line.unit);
    final String name = line.name(language);
    final ProductNames? replacement = question.replacement;
    String perUnit(int? price) =>
        l10n.catalogPricePerUnit(MoneyFormat.uzs(price!, language), unit);
    String quantity(String? value) => '${QuantityRules.display(value!)} $unit';
    String word(ApprovalDecision decision) => switch (decision) {
      ApprovalDecision.approve => l10n.questionApprove,
      ApprovalDecision.reject => l10n.questionReject,
    };

    final String asked = switch (question.type) {
      // A price question with a replacement is about the replacement the
      // Customer authorized; without one, about the product ordered.
      ApprovalType.priceOverTolerance =>
        replacement == null
            ? l10n.questionPrice(
                name,
                perUnit(question.proposedCustomerUnitPriceUzs),
                perUnit(line.customerUnitPriceUzs),
              )
            : l10n.questionReplacementPrice(
                replacement.name(language),
                perUnit(question.proposedCustomerUnitPriceUzs),
              ),
      ApprovalType.substitution => l10n.questionSubstitution(
        name,
        replacement!.name(language),
        perUnit(question.proposedCustomerUnitPriceUzs),
      ),
      ApprovalType.reducedQuantity => l10n.questionQuantity(
        name,
        quantity(question.proposedQuantity),
        quantity(line.quantity),
      ),
    };
    final UnansweredRequest<ApprovalDecision>? unanswered = ref.watch(
      unansweredDecisionsProvider(orderId),
    )[question.id];
    final ApprovalDecisionController decisions = ref.read(
      approvalDecisionProvider((orderId: orderId, lineId: line.id)).notifier,
    );
    VoidCallback? decide(ApprovalDecision decision) =>
        deciding.isBusy ? null : () => decisions.decide(question.id, decision);
    // The decision on its way shows that it is, on its own button.
    Widget label(ApprovalDecision decision, String text) =>
        decisions.sending == decision
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: l10n.decisionSending,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: Text(text)),
            ],
          )
        : Text(text);

    return Card(
      key: ValueKey<String>('question-${question.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(asked, style: Theme.of(context).textTheme.titleSmall),
            if (question.requestNote != null)
              Text(l10n.questionNote(question.requestNote!)),
            Text(l10n.questionExpires(TashkentTime.format(question.expiresAt))),
            // Agreeing to the price of the product ordered drops the
            // replacement the line shows (`docs/09` section 23).
            if (question.type == ApprovalType.priceOverTolerance &&
                replacement == null &&
                line.replacement != null)
              Text(
                l10n.questionDropsReplacement,
                key: ValueKey<String>(
                  'question-drops-replacement-${question.id}',
                ),
              ),
            Text(l10n.questionRejectRemoves),
            const SizedBox(height: 8),
            if (unanswered != null) ...<Widget>[
              Text(
                l10n.decisionUnanswered(word(unanswered.sent)),
                key: ValueKey<String>('decision-unanswered-${question.id}'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: ValueKey<String>('decide-again-${question.id}'),
                onPressed: decide(unanswered.sent),
                child: label(unanswered.sent, l10n.sendAgain),
              ),
            ] else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton(
                    key: ValueKey<String>('approve-${question.id}'),
                    onPressed: decide(ApprovalDecision.approve),
                    child: label(
                      ApprovalDecision.approve,
                      l10n.questionApprove,
                    ),
                  ),
                  OutlinedButton(
                    key: ValueKey<String>('reject-${question.id}'),
                    onPressed: decide(ApprovalDecision.reject),
                    child: label(ApprovalDecision.reject, l10n.questionReject),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A line whose question's time ran out: nothing asks the Customer any more,
/// and staff remove it (`BR-APP-007`).
class OrderQuestionExpired extends StatelessWidget {
  const OrderQuestionExpired({required this.line, super.key});

  final CustomerOrderLine line;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLocalizations.of(context).questionExpired,
      key: ValueKey<String>('question-expired-${line.id}'),
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}
