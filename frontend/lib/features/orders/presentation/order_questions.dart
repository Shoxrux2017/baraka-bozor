import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/idempotency_key.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/platform/clock.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/deadline_chip.dart';
import '../../../core/widgets/product_image.dart';
import '../application/customer_orders_controllers.dart';
import '../domain/customer_orders.dart';

Widget _title(String text) => Text(
  text,
  style: const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: KitColors.warningDark,
  ),
);

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
    final DateTime now = ref.watch(clockProvider)();
    final String unit = CatalogLabels.unit(l10n, line.unit);
    final String name = line.name(language);
    final QuestionReplacement? replacement = question.replacement;
    String perUnit(int? price) =>
        l10n.catalogPricePerUnit(MoneyFormat.uzs(price!, language), unit);
    String quantity(String? value) => '${QuantityRules.display(value!)} $unit';
    // The quantity in force: the one the Customer's yes set, else as ordered.
    final String inForce = quantity(line.agreed?.quantity ?? line.quantity);
    String word(ApprovalDecision decision) => switch (decision) {
      ApprovalDecision.approve => l10n.questionApprove,
      ApprovalDecision.reject => l10n.questionReject,
    };

    final bool substitution = question.type == ApprovalType.substitution;
    final String title = switch (question.type) {
      ApprovalType.priceOverTolerance => l10n.questionFromShopper,
      ApprovalType.substitution => l10n.questionSubstitutionTitle,
      ApprovalType.reducedQuantity => l10n.questionLessTitle,
    };
    final String asked = switch (question.type) {
      // A price question with a replacement is about the replacement the
      // Customer authorized; without one, about the product ordered.
      ApprovalType.priceOverTolerance =>
        replacement == null
            ? l10n.questionPriceKit(
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
      ApprovalType.reducedQuantity => l10n.questionLessKit(
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

    // What a yes leaves on the line, in the words of the question's type.
    final String what = switch (question.type) {
      ApprovalType.priceOverTolerance => inForce,
      ApprovalType.substitution => '${replacement!.name(language)}, $inForce',
      ApprovalType.reducedQuantity => quantity(question.proposedQuantity),
    };
    final String? note = question.requestNote;
    const TextStyle body = TextStyle(fontSize: 13, color: KitColors.ink2);

    return DecoratedBox(
      key: ValueKey<String>('question-${question.id}'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KitColors.warning, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                // The chip speaks the header; with no chip beside it (the
                // phone's clock is past the deadline) the title is the
                // header's one node.
                if (minutesLeft(question.expiresAt, now) > 0)
                  ExcludeSemantics(child: _title(title))
                else
                  Semantics(container: true, child: _title(title)),
                DeadlineChip(
                  deadline: question.expiresAt,
                  onCard: true,
                  spokenTitle: title,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Picture(url: line.imageUrl),
                if (substitution) ...<Widget>[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 20,
                      color: KitColors.muted,
                    ),
                  ),
                  Semantics(
                    container: true,
                    image: true,
                    label: l10n.approvalReplacement(
                      replacement!.name(language),
                    ),
                    excludeSemantics: true,
                    child: _Picture(
                      url: replacement.imageUrl,
                      imageSize: 34,
                      placeholder: true,
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        substitution ? replacement!.name(language) : name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: KitColors.ink,
                        ),
                      ),
                      Text(
                        substitution
                            ? l10n.questionInsteadOf(
                                name,
                                quantity(line.quantity),
                              )
                            : quantity(line.quantity),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: KitColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(asked, style: body),
            if (note != null) ...<Widget>[
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: KitColors.field,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(l10n.questionNoteKit(note), style: body),
                  ),
                ),
              ),
            ],
            // Agreeing to the price of the product ordered drops the
            // replacement the line shows (`docs/09` section 23).
            if (question.type == ApprovalType.priceOverTolerance &&
                replacement == null &&
                line.replacement != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                l10n.questionDropsReplacement,
                key: ValueKey<String>(
                  'question-drops-replacement-${question.id}',
                ),
                style: body,
              ),
            ],
            const SizedBox(height: 12),
            _Effect(
              icon: Icons.check,
              color: KitColors.primary,
              text: TextSpan(
                text: '${l10n.questionEffectApprove(what)} ',
                children: <InlineSpan>[
                  // The estimate's words hold their spaces non-breaking.
                  TextSpan(
                    text: l10n.cartLineEstimate(
                      MoneyFormat.uzs(question.estimateIfApprovedUzs, language),
                    ),
                    style: _bold,
                  ),
                  if (question.changeIfApprovedUzs != 0)
                    TextSpan(
                      text:
                          ' (${MoneyFormat.signed(question.changeIfApprovedUzs)})',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _Effect(
              icon: Icons.close,
              color: KitColors.danger,
              text: TextSpan(
                text: '${l10n.questionEffectReject(name)} ',
                children: <InlineSpan>[
                  TextSpan(
                    text: MoneyFormat.signedUzs(
                      question.changeIfRejectedUzs,
                      language,
                    ),
                    style: _bold,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (unanswered != null) ...<Widget>[
              Text(
                l10n.decisionUnanswered(word(unanswered.sent)),
                key: ValueKey<String>('decision-unanswered-${question.id}'),
                style: body,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: ValueKey<String>('decide-again-${question.id}'),
                  style: _buttonStyle,
                  onPressed: decide(unanswered.sent),
                  child: label(unanswered.sent, l10n.sendAgain),
                ),
              ),
            ] else
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      key: ValueKey<String>('reject-${question.id}'),
                      style: _buttonStyle,
                      onPressed: decide(ApprovalDecision.reject),
                      child: label(
                        ApprovalDecision.reject,
                        l10n.questionReject,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      key: ValueKey<String>('approve-${question.id}'),
                      style: _buttonStyle,
                      onPressed: decide(ApprovalDecision.approve),
                      child: label(
                        ApprovalDecision.approve,
                        l10n.questionApprove,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

const TextStyle _bold = TextStyle(
  fontSize: 13,
  height: 1.4,
  fontWeight: FontWeight.w700,
  color: KitColors.ink,
);

/// One of the two lines saying what an answer does to the bill: a 17 px icon
/// and the words (`DL-130`).
class _Effect extends StatelessWidget {
  const _Effect({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final TextSpan text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ExcludeSemantics(
          child: Padding(
            // Centres the icon on the first line of 13 px text at height 1.4.
            padding: const EdgeInsets.only(top: 0.6),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: KitColors.ink2,
            ),
          ),
        ),
      ],
    );
  }
}

final ButtonStyle _buttonStyle = ButtonStyle(
  minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 46)),
  shape: WidgetStatePropertyAll<OutlinedBorder>(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
);

const ColorFilter _grey = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// A product picture on the kit's `card` square; without a [url], an empty
/// well.
class _Picture extends StatelessWidget {
  const _Picture({
    required this.url,
    this.size = 48,
    this.imageSize,
    this.placeholder = false,
    this.greyed = false,
  });

  final String? url;
  final double size;

  /// The picture's own size inside the box, [size] when not set.
  final double? imageSize;

  /// Draws the product placeholder when there is no [url].
  final bool placeholder;
  final bool greyed;

  @override
  Widget build(BuildContext context) {
    Widget picture = url == null && !placeholder
        ? const SizedBox.shrink()
        : ProductImage(url: url, size: imageSize ?? size);
    if (greyed) {
      picture = Opacity(
        opacity: 0.4,
        child: ColorFiltered(colorFilter: _grey, child: picture),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Center(child: picture),
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DecoratedBox(
      key: ValueKey<String>('question-expired-${line.id}'),
      decoration: BoxDecoration(
        color: KitColors.field,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.questionExpiredTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: KitColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Picture(url: line.imageUrl, size: 40, greyed: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        line.name(interfaceLanguage(context)),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: KitColors.muted,
                        ),
                      ),
                      Text(
                        l10n.questionExpiredLine,
                        style: const TextStyle(
                          fontSize: 13,
                          color: KitColors.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
