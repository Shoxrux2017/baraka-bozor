import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit/kit_dialog.dart';
import '../../../core/widgets/kit/kit_fields.dart';
import '../../../core/widgets/kit/kit_note.dart';
import '../../../core/widgets/panel/panel_card.dart';
import '../../../core/widgets/panel/panel_fields.dart';
import '../../../core/widgets/panel/panel_layout.dart';
import '../../../core/widgets/panel/panel_page_header.dart';
import '../../../core/widgets/panel/panel_person.dart';
import '../application/admin_customers_controllers.dart';
import '../domain/admin_customers.dart';
import 'staff_widgets.dart';

/// The phone a search text names: its digits, nine of them after the fixed
/// `+998`, or twelve of a whole pasted number starting `998`. `null` for
/// anything else.
String? customerPhoneOf(String text) {
  final String digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.length == phoneNationalDigits) {
    return '$phoneCountryCode$digits';
  }
  if (digits.length == phoneCountryCode.length - 1 + phoneNationalDigits &&
      digits.startsWith('998')) {
    return '+$digits';
  }
  return null;
}

/// The Admin's Customer accounts (`docs/09-api-contracts.md` sections 66
/// and 67): the accounts on the number a caller rang from, and the erasure
/// of one of them on request.
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  /// The page content width from which the help card stands beside the
  /// search and its results; below it the card sits under them.
  static const double twoColumnsWidth = 1000;

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final TextEditingController _phoneField = TextEditingController();
  bool _malformed = false;

  @override
  void dispose() {
    _phoneField.dispose();
    super.dispose();
  }

  void _find() {
    final String? phone = customerPhoneOf(_phoneField.text);
    if (phone == null) {
      setState(() => _malformed = true);
      return;
    }
    setState(() => _malformed = false);
    ref.read(customerSearchProvider.notifier).find(phone);
  }

  Future<void> _erase(AdminCustomer customer) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool? confirmed = await showKitDialog<bool>(
      context: context,
      dialogKey: 'customer-erase-dialog',
      title: l10n.customerEraseTitle,
      badge: const KitDialogBadge(Icons.person_remove_outlined, danger: true),
      builder: (BuildContext context) => _EraseQuestion(customer: customer),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final bool erased = await ref
        .read(eraseCustomerControllerProvider.notifier)
        .erase(customer.id);
    if (erased) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.customerErased)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<AdminCustomer>>? found = ref.watch(
      customerSearchProvider,
    );
    final MutationState erasing = ref.watch(eraseCustomerControllerProvider);
    final ApiFailure? failure = erasing.failure;
    final ({String id, int number})? blockedBy = failure?.unfinishedOrder;
    final EdgeInsets padding = panelPagePadding(
      MediaQuery.sizeOf(context).width,
    );

    final Widget left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PanelCard(
          key: const ValueKey<String>('customers-search'),
          children: <Widget>[
            KitLabeledField(
              label: l10n.customersPhoneLabel,
              field: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // The button is as high as the field, so the two line up.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: TextField(
                              key: const ValueKey<String>('customers-phone'),
                              controller: _phoneField,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.search,
                              style: panelFieldTextStyle,
                              onSubmitted: (String _) => _find(),
                              decoration:
                                  panelFieldDecoration(
                                    prefix: phoneCountryCode,
                                    hint: l10n.phoneHint,
                                  ).copyWith(
                                    errorText: _malformed
                                        ? l10n.customersPhoneHint
                                        : null,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          key: const ValueKey<String>('customers-find'),
                          style: kitFilled(height: 44),
                          onPressed: _find,
                          icon: const Icon(Icons.search, size: 20),
                          label: Text(l10n.customersFind),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.customersPhoneHelper,
                    style: const TextStyle(
                      fontSize: 11,
                      color: KitColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (blockedBy != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              l10n.customerUnfinished('${blockedBy.number}'),
              style: const TextStyle(fontSize: 13, color: KitColors.dangerDark),
            ),
          )
        else
          FailureMessage(failure),
        const SizedBox(height: 16),
        Column(
          key: const ValueKey<String>('customers-results'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (found == null)
              _EmptyCard(
                icon: Icons.person_search,
                title: l10n.customersStartTitle,
                text: l10n.customersStartText,
              )
            else
              found.when(
                skipLoadingOnReload: false,
                skipLoadingOnRefresh: !found.hasError,
                data: (List<AdminCustomer> customers) => customers.isEmpty
                    ? _EmptyCard(
                        icon: Icons.search_off,
                        title: l10n.customersNone,
                        text: l10n.customersNoneHint,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (final AdminCustomer customer in customers)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _CustomerCard(
                                customer: customer,
                                busy: erasing.isBusy,
                                onErase: () => _erase(customer),
                              ),
                            ),
                        ],
                      ),
                error: (Object error, StackTrace _) => FailureMessage(
                  error is ApiFailure ? error : const UnexpectedFailure(),
                ),
                loading: () => const PanelCard(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool beside =
            constraints.maxWidth - padding.horizontal >=
            CustomersScreen.twoColumnsWidth;
        final Widget help = _HelpCard(l10n: l10n);

        return ListView(
          padding: padding,
          children: <Widget>[
            PanelPageHeader(
              title: l10n.customersTitle,
              subtitle: l10n.customersSubtitle,
            ),
            const SizedBox(height: 18),
            if (beside)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: left),
                  const SizedBox(width: 20),
                  SizedBox(width: 372, child: help),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[left, const SizedBox(height: 16), help],
              ),
          ],
        );
      },
    );
  }
}

/// An empty state in a card: an icon in a green circle, a title and a text.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: KitColors.primaryWash,
                ),
                child: Icon(icon, size: 32, color: KitColors.primaryDark),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: KitColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: KitColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.busy,
    required this.onErase,
  });

  final AdminCustomer customer;
  final bool busy;
  final VoidCallback onErase;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ({String id, int number})? unfinished = customer.unfinishedOrder;
    final DateTime? lastLogin = customer.lastLoginAt;

    return PanelCard(
      key: ValueKey<String>('customer-${customer.id}'),
      children: <Widget>[
        Row(
          children: <Widget>[
            PersonAvatar(customer.fullName, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        customer.fullName ?? l10n.customerNoName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: KitColors.ink,
                        ),
                      ),
                      AccountStatusChip(blocked: customer.isBlocked),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatPhone(customer.phone),
                    style: const TextStyle(fontSize: 14, color: KitColors.ink2),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PanelFieldRow(
          minFieldWidth: 150,
          children: <Widget>[
            _FieldBox(
              label: l10n.customerOrdersLabel,
              value: '${customer.orderCount}',
            ),
            _FieldBox(
              label: l10n.customerSince,
              value: TashkentTime.date(customer.createdAt),
            ),
            _FieldBox(
              label: l10n.customerLastLoginLabel,
              value: lastLogin == null ? '—' : TashkentTime.format(lastLogin),
            ),
          ],
        ),
        if (unfinished != null) ...<Widget>[
          const SizedBox(height: 14),
          KitNote(
            icon: Icons.schedule,
            tone: KitTone.amber,
            text: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.customerUnfinished('${unfinished.number}'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(l10n.customerUnfinishedExplained),
              ],
            ),
          ),
        ],
        if (customer.isBlocked) ...<Widget>[
          const SizedBox(height: 14),
          KitNote(
            icon: Icons.block,
            tone: KitTone.amber,
            text: Text(l10n.customerEraseBlockedNote),
          ),
        ],
        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 1, color: KitColors.line),
        const SizedBox(height: 16),
        _DangerRow(
          customer: customer,
          enabled: unfinished == null && !busy,
          onErase: onErase,
        ),
      ],
    );
  }
}

/// The erasure's title and what it does at the left, its button at the right
/// (under them when the card is narrow or the text large).
class _DangerRow extends StatelessWidget {
  const _DangerRow({
    required this.customer,
    required this.enabled,
    required this.onErase,
  });

  final AdminCustomer customer;
  final bool enabled;
  final VoidCallback onErase;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    final Widget text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.customerErase,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: KitColors.dangerDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.customerEraseBody,
          style: const TextStyle(fontSize: 12, color: KitColors.ink2),
        ),
      ],
    );
    final Widget button = OutlinedButton.icon(
      key: ValueKey<String>('customer-erase-${customer.id}'),
      style: kitOutlined(foreground: KitColors.dangerDark, height: 44).copyWith(
        side: WidgetStateProperty.resolveWith<BorderSide>(
          (Set<WidgetState> states) => BorderSide(
            color: states.contains(WidgetState.disabled)
                ? KitColors.line
                : KitColors.danger,
          ),
        ),
      ),
      onPressed: enabled ? onErase : null,
      icon: const Icon(Icons.person_remove_outlined, size: 20),
      label: Text(l10n.customerErase),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= 480 && !kitLargeText(context)) {
          return Row(
            children: <Widget>[
              Expanded(child: text),
              const SizedBox(width: 16),
              button,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[text, const SizedBox(height: 12), button],
        );
      },
    );
  }
}

/// A labelled figure on a `field` box.
class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.field,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: KitColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The question an erasure asks: whose account, what goes, that it is final.
class _EraseQuestion extends StatelessWidget {
  const _EraseQuestion({required this.customer});

  final AdminCustomer customer;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    const TextStyle body = TextStyle(fontSize: 13, color: KitColors.ink2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: KitColors.field,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: PanelPersonLine(
              name: customer.fullName ?? l10n.customerNoName,
              detail:
                  '${formatPhone(customer.phone)} · '
                  '${l10n.customerOrders(customer.orderCount)}',
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(l10n.customerEraseBody, style: body),
        const SizedBox(height: 6),
        Text(l10n.customerEraseFinal, style: body),
        if (customer.isBlocked) ...<Widget>[
          const SizedBox(height: 14),
          KitNote(
            icon: Icons.block,
            tone: KitTone.amber,
            text: Text(l10n.customerEraseBlockedNote),
          ),
        ],
        const SizedBox(height: 20),
        kitDialogButtons(
          context: context,
          busy: false,
          confirmKey: const ValueKey<String>('customer-erase-confirm'),
          confirm: l10n.customerEraseConfirm,
          confirmIcon: Icons.delete_outline,
          destructive: true,
          submit: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

/// How an erasure on request goes, and that the panel never lists Customers.
class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final List<String> steps = <String>[
      l10n.customersHelpStep1,
      l10n.customersHelpStep2,
      l10n.customersHelpStep3,
    ];

    return PanelCard(
      key: const ValueKey<String>('customers-help'),
      title: l10n.customersHelpTitle,
      children: <Widget>[
        const SizedBox(height: 16),
        for (int i = 0; i < steps.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: KitColors.primaryWash,
                ),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: KitColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  steps[i],
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: KitColors.ink2,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        KitNote(
          icon: Icons.lock_outline,
          tone: KitTone.grey,
          text: Text(l10n.customersHelpPrivacy),
        ),
      ],
    );
  }
}
