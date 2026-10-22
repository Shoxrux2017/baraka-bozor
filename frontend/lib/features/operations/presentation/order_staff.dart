import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit/kit_note.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/panel/panel_card.dart';
import '../application/board_controllers.dart';
import '../domain/board.dart';
import 'board_widgets.dart';
import 'order_actions.dart';

/// A round avatar with the initials of [name], green on its wash.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar(this.name, {super.key});

  final String? name;

  String get _initials {
    final List<String> words = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return '?';
    }
    final String first = String.fromCharCode(words.first.runes.first);
    final String second = words.length > 1
        ? String.fromCharCode(words[1].runes.first)
        : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: KitColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: KitColors.primaryDark,
        ),
      ),
    );
  }
}

/// One assignment as a person: avatar, name with its tags, phone, and the
/// lines of who assigned it and what became of it, in muted 12.
class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({
    required this.rowKey,
    required this.name,
    required this.phone,
    required this.current,
    required this.selfOrder,
    required this.failed,
    required this.lines,
  });

  final Key rowKey;
  final String name;
  final String phone;
  final bool current;
  final bool selfOrder;
  final bool failed;
  final List<Widget> lines;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      key: rowKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            PersonAvatar(name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: KitColors.ink,
                        ),
                      ),
                      if (current)
                        KitTag(
                          text: l10n.assignmentCurrent,
                          tone: KitTone.green,
                        )
                      else if (failed)
                        KitTag(
                          text: l10n.courierEndDeliveryFailed,
                          tone: KitTone.red,
                        ),
                      if (selfOrder) const SelfOrderMark(),
                    ],
                  ),
                  Text(
                    phone,
                    style: const TextStyle(fontSize: 12, color: KitColors.ink2),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (lines.isNotEmpty) ...<Widget>[const SizedBox(height: 8), ...lines],
      ],
    );
  }
}

Widget _line(String text, {Key? key, Color color = KitColors.muted}) => Text(
  text,
  key: key,
  style: TextStyle(fontSize: 12, color: color),
);

/// Whether a card [constraints] wide has room for the reassign button in its
/// header beside the title: from 360, and not at large text. Narrower, the
/// button goes under the rows.
bool _reassignInHeader(BuildContext context, BoxConstraints constraints) =>
    constraints.maxWidth >= 360 && !kitLargeText(context);

/// A rule between a card's rows.
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, thickness: 1, color: KitColors.line),
  );
}

/// The Shopper card: the current Shopper and the earlier ones, with the way
/// to assign one to a `new` order or to replace the one who has not started
/// (`BR-ASSIGN-001`, `BR-ASSIGN-002`).
class ShopperCard extends StatelessWidget {
  const ShopperCard({required this.order, super.key});

  final BoardOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ShopperAssignment? current = order.currentAssignment;
    final List<ShopperAssignment> assignments = order
        .shopperAssignments
        .reversed
        .toList();

    AssignmentActions actions({required bool header}) => AssignmentActions(
      header: header,
      order: order,
      assignment: shopperAssignmentProvider(order.id),
      options: shopperOptionsProvider,
      role: 'shopper',
      assigns: order.status == OrderStatus.newOrder && current == null,
      reassigns:
          order.status == OrderStatus.shoppingAssigned &&
          current != null &&
          current.startedAt == null,
      current: current == null
          ? null
          : (id: current.id, staffId: current.shopper.id),
      words: (
        pickTitle: l10n.pickShopperTitle,
        pickEmpty: l10n.pickShopperEmpty,
        assign: l10n.assignShopper,
        reassign: l10n.reassignShopper,
        busy: l10n.assigningShopper,
      ),
      assignIcon: Icons.person_add_alt_1_outlined,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool inHeader = _reassignInHeader(context, constraints);

        return PanelCard(
          title: l10n.orderSectionShoppers,
          trailing: inHeader ? actions(header: true) : null,
          children: <Widget>[
            const SizedBox(height: 14),
            if (assignments.isEmpty)
              Text(
                l10n.assignmentsNone,
                style: const TextStyle(fontSize: 13, color: KitColors.muted),
              ),
            for (
              int index = 0;
              index < assignments.length;
              index++
            ) ...<Widget>[
              if (index > 0) const _Rule(),
              _shopperRow(l10n, assignments[index]),
            ],
            if (!inHeader) actions(header: true),
            actions(header: false),
          ],
        );
      },
    );
  }

  Widget _shopperRow(AppLocalizations l10n, ShopperAssignment assignment) {
    final DateTime? endedAt = assignment.endedAt;

    return _AssignmentRow(
      rowKey: ValueKey<String>('assignment-${assignment.id}'),
      name: nameOf(l10n, assignment.shopper),
      phone: formatPhone(assignment.shopperPhone),
      current: endedAt == null,
      selfOrder: assignment.isSelfOrder,
      failed: false,
      lines: <Widget>[
        _line(
          l10n.assignmentAssignedBy(
            nameOf(l10n, assignment.assignedBy),
            TashkentTime.format(assignment.assignedAt),
          ),
        ),
        if (assignment.acceptedAt != null)
          _line(
            l10n.assignmentAccepted(
              TashkentTime.format(assignment.acceptedAt!),
            ),
          ),
        if (assignment.startedAt != null)
          _line(
            l10n.assignmentStarted(TashkentTime.format(assignment.startedAt!)),
          ),
        if (endedAt != null)
          _line(
            l10n.assignmentEnded(
              TashkentTime.format(endedAt),
              _endReason(l10n, assignment.endedReason!),
            ),
          ),
      ],
    );
  }

  static String _endReason(AppLocalizations l10n, AssignmentEndReason reason) =>
      switch (reason) {
        AssignmentEndReason.completed => l10n.assignmentEndCompleted,
        AssignmentEndReason.reassigned => l10n.assignmentEndReassigned,
        // A Shopper's assignment never ends so, and the parser refuses it;
        // the case keeps the switch whole.
        AssignmentEndReason.deliveryFailed => l10n.courierEndDeliveryFailed,
        AssignmentEndReason.orderCancelled => l10n.assignmentEndOrderCancelled,
      };
}

/// The Courier card, with the rules of the Shopper's (`DL-48`, `DL-54` (10)):
/// assign while the order is ready and has no Courier, reassign while it is
/// assigned and the Courier has not set off. After a failed delivery it is
/// outlined in red, with the choice of a new Courier or the end of the order
/// (`DL-68`).
class CourierCard extends StatelessWidget {
  const CourierCard({required this.order, super.key});

  final BoardOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CourierAssignment? current = order.currentCourierAssignment;
    final List<CourierAssignment> assignments = order
        .courierAssignments
        .reversed
        .toList();
    final bool assigns =
        order.status == OrderStatus.readyForDelivery && current == null;
    final bool failedLast =
        order.status == OrderStatus.readyForDelivery &&
        assignments.isNotEmpty &&
        assignments.first.endedReason == AssignmentEndReason.deliveryFailed;
    final bool notYet =
        assignments.isEmpty &&
        !assigns &&
        order.status.index < OrderStatus.readyForDelivery.index;

    AssignmentActions actions({required bool header}) => AssignmentActions(
      header: header,
      order: order,
      assignment: courierAssignmentProvider(order.id),
      options: courierOptionsProvider,
      role: 'courier',
      assigns: assigns,
      reassigns:
          order.status == OrderStatus.deliveryAssigned &&
          current != null &&
          current.deliveryStartedAt == null,
      current: current == null
          ? null
          : (id: current.id, staffId: current.courier.id),
      words: (
        pickTitle: l10n.pickCourierTitle,
        pickEmpty: l10n.pickCourierEmpty,
        assign: l10n.assignCourier,
        reassign: l10n.reassignCourier,
        busy: l10n.assigningCourier,
      ),
      assignIcon: Icons.delivery_dining_outlined,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool inHeader = _reassignInHeader(context, constraints);

        return PanelCard(
          title: l10n.orderSectionCouriers,
          trailing: inHeader ? actions(header: true) : null,
          tone: failedLast ? KitTone.red : null,
          children: <Widget>[
            const SizedBox(height: 14),
            if (assignments.isEmpty) ...<Widget>[
              Text(
                l10n.courierAssignmentsNone,
                style: const TextStyle(fontSize: 13, color: KitColors.muted),
              ),
              if (notYet)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l10n.orderCourierLater,
                    style: const TextStyle(
                      fontSize: 12,
                      color: KitColors.muted,
                    ),
                  ),
                ),
            ],
            for (
              int index = 0;
              index < assignments.length;
              index++
            ) ...<Widget>[
              if (index > 0) const _Rule(),
              _courierRow(l10n, assignments[index]),
            ],
            if (!inHeader) actions(header: true),
            if (order.cancellableAfterFailedDelivery)
              _Pair(
                first: actions(header: false),
                second: FailedDeliveryCancel(order: order),
              )
            else
              actions(header: false),
          ],
        );
      },
    );
  }

  Widget _courierRow(AppLocalizations l10n, CourierAssignment assignment) {
    final DateTime? endedAt = assignment.endedAt;
    final DeliveryFailureReason? failed = assignment.failedReason;

    return _AssignmentRow(
      rowKey: ValueKey<String>('courier-assignment-${assignment.id}'),
      name: nameOf(l10n, assignment.courier),
      phone: formatPhone(assignment.courierPhone),
      current: endedAt == null,
      selfOrder: assignment.isSelfOrder,
      failed: failed != null,
      lines: <Widget>[
        _line(
          l10n.assignmentAssignedBy(
            nameOf(l10n, assignment.assignedBy),
            TashkentTime.format(assignment.assignedAt),
          ),
        ),
        if (assignment.acceptedAt != null)
          _line(
            l10n.assignmentAccepted(
              TashkentTime.format(assignment.acceptedAt!),
            ),
          ),
        if (assignment.deliveryStartedAt != null)
          _line(
            l10n.courierStarted(
              TashkentTime.format(assignment.deliveryStartedAt!),
            ),
          ),
        if (endedAt != null)
          _line(
            l10n.assignmentEnded(
              TashkentTime.format(endedAt),
              _endReason(l10n, assignment.endedReason!),
            ),
          ),
        if (failed != null)
          _line(
            <String>[
              OrderLabels.deliveryFailure(l10n, failed),
              if (assignment.failedNote != null) assignment.failedNote!,
            ].join(': '),
            key: ValueKey<String>('courier-failure-${assignment.id}'),
            color: KitColors.dangerDark,
          ),
      ],
    );
  }

  static String _endReason(AppLocalizations l10n, AssignmentEndReason reason) =>
      switch (reason) {
        AssignmentEndReason.completed => l10n.courierEndCompleted,
        AssignmentEndReason.reassigned => l10n.courierEndReassigned,
        AssignmentEndReason.deliveryFailed => l10n.courierEndDeliveryFailed,
        AssignmentEndReason.orderCancelled => l10n.assignmentEndOrderCancelled,
      };
}

/// Two buttons side by side, each half the width; past large text, stacked.
class _Pair extends StatelessWidget {
  const _Pair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    if (kitLargeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[first, const SizedBox(height: 10), second],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: first),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: second,
          ),
        ),
      ],
    );
  }
}

/// One role's assignment actions and what the last attempt answered: with
/// [header] the reassign button for the card's header; without it the
/// assign button, full width, and the refusal below. The buttons follow the
/// order as loaded; the server decides, and a conflict reloads the order and
/// says why.
class AssignmentActions extends ConsumerWidget {
  const AssignmentActions({
    required this.header,
    required this.order,
    required this.assignment,
    required this.options,
    required this.role,
    required this.assigns,
    required this.reassigns,
    required this.current,
    required this.words,
    required this.assignIcon,
    super.key,
  });

  final bool header;
  final BoardOrder order;
  final NotifierProvider<StaffAssignmentController, MutationState> assignment;
  final FutureProvider<List<StaffChoice>> options;

  /// `shopper` or `courier`, as the keys name it.
  final String role;
  final bool assigns;
  final bool reassigns;

  /// The current assignment and the Shopper or the Courier it names.
  final ({String id, String staffId})? current;
  final ({
    String pickTitle,
    String pickEmpty,
    String assign,
    String reassign,
    String busy,
  })
  words;
  final IconData assignIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MutationState state = ref.watch(assignment);
    // Until the order the last change reloaded has arrived, the buttons
    // would act on the order as it was.
    final bool busy =
        state.isBusy || ref.watch(boardOrderProvider(order.id)).isLoading;

    Future<void> pick() async {
      final StaffChoice? chosen = await showDialog<StaffChoice>(
        context: context,
        builder: (BuildContext context) => StaffPicker(
          options: options,
          title: words.pickTitle,
          empty: words.pickEmpty,
          keyPrefix: 'pick-$role',
          currentId: current?.staffId,
        ),
      );
      if (chosen == null || !context.mounted) {
        return;
      }
      final StaffAssignmentController change = ref.read(assignment.notifier);
      final ({String id, String staffId})? replaced = current;
      if (replaced == null) {
        await change.assign(chosen.id);
      } else {
        await change.reassign(chosen.id, replaced.id);
      }
    }

    Widget label(String text, IconData icon) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (state.isBusy)
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: KitColors.muted,
              semanticsLabel: words.busy,
            ),
          )
        else
          Icon(icon, size: 20),
        const SizedBox(width: 8),
        Flexible(child: Text(state.isBusy ? words.busy : text)),
      ],
    );

    if (header) {
      if (!reassigns) {
        return const SizedBox.shrink();
      }
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: OutlinedButton(
          key: ValueKey<String>('reassign-$role'),
          style: kitOutlined(height: 40)
              .copyWith(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          onPressed: busy ? null : pick,
          child: label(words.reassign, Icons.swap_horiz),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (assigns)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FilledButton(
              key: ValueKey<String>('assign-$role'),
              style: kitFilled(height: 44)
                  .copyWith(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: busy ? null : pick,
              child: label(words.assign, assignIcon),
            ),
          ),
        FailureMessage(state.failure),
      ],
    );
  }
}

/// The active Shoppers or Couriers to choose from, each with the orders in
/// their hands now; the current one is shown but not offered.
class StaffPicker extends ConsumerWidget {
  const StaffPicker({
    required this.options,
    required this.title,
    required this.empty,
    required this.keyPrefix,
    required this.currentId,
    super.key,
  });

  final FutureProvider<List<StaffChoice>> options;
  final String title;
  final String empty;
  final String keyPrefix;
  final String? currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<StaffChoice>> choices = ref.watch(options);

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: choices.when(
          skipLoadingOnRefresh: !choices.hasError,
          data: (List<StaffChoice> choices) => choices.isEmpty
              ? Text(empty)
              : ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final StaffChoice choice in choices)
                      ListTile(
                        key: ValueKey<String>('$keyPrefix-${choice.id}'),
                        enabled: choice.id != currentId,
                        title: Text(
                          choice.fullName ?? formatPhone(choice.phone),
                        ),
                        subtitle: Text(
                          '${formatPhone(choice.phone)} · '
                          '${l10n.shopperOrdersNow(choice.currentAssignmentCount)}',
                        ),
                        trailing: choice.id == currentId
                            ? Text(l10n.assignmentCurrent)
                            : null,
                        onTap: () => Navigator.of(context).pop(choice),
                      ),
                  ],
                ),
          // Both keep the dialog as small as what they show.
          error: (Object error, StackTrace _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LoadFailure(error: error, onRetry: () => ref.invalidate(options)),
            ],
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(heightFactor: 1, child: CircularProgressIndicator()),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: ValueKey<String>('$keyPrefix-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
      ],
    );
  }
}
