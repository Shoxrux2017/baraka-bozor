import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/role_labels.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/paged.dart';
import '../../../core/session/staff_account.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit/kit_card.dart';
import '../../../core/widgets/kit/kit_dialog.dart';
import '../../../core/widgets/kit/kit_fields.dart';
import '../../../core/widgets/kit/kit_note.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/panel/panel_action_button.dart';
import '../../../core/widgets/panel/panel_card.dart';
import '../../../core/widgets/panel/panel_fields.dart';
import '../../../core/widgets/panel/panel_layout.dart';
import '../../../core/widgets/panel/panel_menu_button.dart';
import '../../../core/widgets/panel/panel_page_header.dart';
import '../../../core/widgets/panel/panel_pager.dart';
import '../../../core/widgets/panel/panel_person.dart';
import '../../../core/widgets/panel/panel_pills.dart';
import '../../../core/widgets/panel/panel_table.dart';
import '../../auth/domain/app_user.dart';
import '../../operations/application/board_controllers.dart';
import '../../operations/domain/board.dart';
import '../application/admin_staff_controllers.dart';
import '../domain/admin_staff.dart';
import 'catalog_form_rules.dart';
import 'catalog_widgets.dart';
import 'staff_widgets.dart';

/// The Admin's staff accounts (`docs/09-api-contracts.md` section 43,
/// `docs/04-user-flows.md` section 32): the list with its role and status
/// filters, creation with a temporary password shown once, the name, block
/// and activate, and a password reset (`DL-102` (2)). It is a table from a
/// card [tableWidth] wide and cards below it.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  /// From this card width the staff are a table whose columns all show, and
  /// the role pills wrap beside the status menu; below it, cards, a row of
  /// pills that scrolls and the menu under it.
  static const double tableWidth = 800;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final StaffQuery query = ref.watch(staffQueryProvider);
    final StaffQueryController queries = ref.read(staffQueryProvider.notifier);
    final AsyncValue<Paged<StaffMember>> page = ref.watch(staffPageProvider);
    final MutationState actions = ref.watch(staffListActionsProvider);
    final EdgeInsets padding = panelPagePadding(
      MediaQuery.sizeOf(context).width,
    );
    final bool filtered = query.role != null || query.status != null;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool labelled =
            constraints.maxWidth - padding.horizontal >= 480 &&
            !kitLargeText(context);

        return ListView(
          padding: padding,
          children: <Widget>[
            PanelPageHeader(
              title: l10n.adminSectionStaff,
              subtitle: page.hasValue
                  ? l10n.staffCount(page.requireValue.total)
                  : null,
              trailing: PanelHeaderButton(
                buttonKey: const ValueKey<String>('new-staff'),
                icon: Icons.person_add_alt,
                label: l10n.staffNew,
                labelled: labelled,
                onPressed: () => _showStaffWindow(
                  context,
                  (BuildContext context) => const _NewStaffDialog(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            PanelCard(
              flush: true,
              children: <Widget>[
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints card) {
                    final bool table = card.maxWidth >= tableWidth;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _StaffFilters(
                          query: query,
                          queries: queries,
                          beside: table,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: FailureMessage(actions.failure),
                        ),
                        page.when(
                          skipLoadingOnReload: false,
                          skipLoadingOnRefresh: !page.hasError,
                          data: (Paged<StaffMember> page) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              if (page.items.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(l10n.catalogEmpty),
                                      if (filtered)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            l10n.staffEmptyHint,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: KitColors.muted,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              else if (table)
                                _StaffTable(
                                  members: page.items,
                                  busy: actions.isBusy,
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    6,
                                  ),
                                  child: Column(
                                    children: <Widget>[
                                      for (final StaffMember member
                                          in page.items)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: _StaffCard(
                                            member: member,
                                            busy: actions.isBusy,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              PanelPager(page: page, onPage: queries.goToPage),
                            ],
                          ),
                          error: (Object error, StackTrace _) => LoadFailure(
                            error: error,
                            onRetry: () => ref.invalidate(staffPageProvider),
                          ),
                          loading: () => const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

String _roleFilterLabel(AppLocalizations l10n, UserRole role) => switch (role) {
  UserRole.shopper => l10n.staffRoleShoppers,
  UserRole.courier => l10n.staffRoleCouriers,
  UserRole.operator => l10n.staffRoleOperators,
  UserRole.admin => l10n.staffRoleAdmins,
  UserRole.manager => l10n.staffRoleManagers,
  UserRole.customer => l10n.shellCustomer,
};

/// The role pills and the status menu: side by side from a card
/// [StaffScreen.tableWidth] wide (the pills wrap), the menu under a scrolling
/// row of pills below it.
class _StaffFilters extends StatelessWidget {
  const _StaffFilters({
    required this.query,
    required this.queries,
    required this.beside,
  });

  final StaffQuery query;
  final StaffQueryController queries;
  final bool beside;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    final Widget pills = PanelPillRow(
      wrap: beside,
      pills: <Widget>[
        PanelPill(
          key: const ValueKey<String>('staff-role-all'),
          label: l10n.staffAllRoles,
          selected: query.role == null,
          onTap: () => queries.filterByRole(null),
        ),
        for (final UserRole role in staffRoles)
          PanelPill(
            key: ValueKey<String>('staff-role-${role.name}'),
            label: _roleFilterLabel(l10n, role),
            selected: query.role == role,
            onTap: () => queries.filterByRole(role),
          ),
      ],
    );

    final AccountStatus? status = query.status;
    final Widget menu = SizedBox(
      width: 200,
      child: PanelMenuButton<AccountStatus?>(
        buttonKey: 'staff-status-filter',
        label: switch (status) {
          null => l10n.staffAllStatuses,
          AccountStatus.active => l10n.statusActive,
          AccountStatus.blocked => l10n.statusBlocked,
        },
        active: status != null,
        items: <PanelMenuItem<AccountStatus?>>[
          (value: null, label: l10n.staffAllStatuses),
          (value: AccountStatus.active, label: l10n.statusActive),
          (value: AccountStatus.blocked, label: l10n.statusBlocked),
        ],
        onSelected: queries.filterByStatus,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: beside
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: pills),
                const SizedBox(width: 16),
                menu,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                pills,
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerLeft, child: menu),
              ],
            ),
    );
  }
}

/// The staff as a table: the member, the role, the status and the last
/// sign-in, then the actions.
class _StaffTable extends StatelessWidget {
  const _StaffTable({required this.members, required this.busy});

  final List<StaffMember> members;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return PanelTable(
      columns: <PanelColumn>[
        (
          label: l10n.staffColumnMember,
          width: const FlexColumnWidth(3),
          end: false,
        ),
        (
          label: l10n.staffRole,
          // A role's name never breaks mid-word.
          width: const MaxColumnWidth(
            FixedColumnWidth(170),
            FlexColumnWidth(1.6),
          ),
          end: false,
        ),
        (
          label: l10n.staffColumnStatus,
          width: const FlexColumnWidth(1.6),
          end: false,
        ),
        (
          label: l10n.staffColumnLastLogin,
          width: const FlexColumnWidth(1.6),
          end: false,
        ),
        (label: '', width: const FixedColumnWidth(140), end: true),
      ],
      rows: <PanelTableRow>[
        for (final StaffMember member in members) _row(context, l10n, member),
      ],
    );
  }

  PanelTableRow _row(
    BuildContext context,
    AppLocalizations l10n,
    StaffMember member,
  ) {
    final bool blocked = member.status == AccountStatus.blocked;
    final DateTime? lastLogin = member.lastLoginAt;

    return PanelTableRow(
      key: ValueKey<String>('staff-${member.id}'),
      faded: blocked,
      lastCellPadding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      cells: <Widget>[
        _StaffPerson(member: member),
        StaffRoleChip(member.role),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AccountStatusChip(blocked: blocked),
            if (member.mustChangePassword) ...<Widget>[
              const SizedBox(height: 6),
              const MustChangePasswordTag(),
            ],
          ],
        ),
        Text(
          lastLogin == null
              ? l10n.staffNeverLoggedIn
              : TashkentTime.format(lastLogin),
          style: TextStyle(
            fontSize: 13,
            color: lastLogin == null ? KitColors.muted : KitColors.ink2,
          ),
        ),
        _StaffActions(member: member, busy: busy),
      ],
    );
  }
}

/// The member as a person line, with the "you" tag on the Admin's own.
class _StaffPerson extends ConsumerWidget {
  const _StaffPerson({required this.member});

  final StaffMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return PanelPersonLine(
      name: member.fullName ?? l10n.staffNoName,
      detail: formatPhone(member.phone),
      muted: member.status == AccountStatus.blocked,
      tags: member.id == ref.watch(staffAccountProvider)
          ? <Widget>[OwnTag(key: ValueKey<String>('own-${member.id}'))]
          : const <Widget>[],
    );
  }
}

/// A member as a card: the person and the actions, and under them the role,
/// the status, the tag and the last sign-in.
class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.member, required this.busy});

  final StaffMember member;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool blocked = member.status == AccountStatus.blocked;
    final DateTime? lastLogin = member.lastLoginAt;

    return KitCard(
      key: ValueKey<String>('staff-${member.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: blocked ? KitColors.card : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _StaffPerson(member: member)),
              const SizedBox(width: 8),
              _StaffActions(member: member, busy: busy),
            ],
          ),
          const SizedBox(height: 12),
          const DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: KitColors.line)),
            ),
            child: SizedBox(height: 12),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              StaffRoleChip(member.role),
              AccountStatusChip(blocked: blocked),
              if (member.mustChangePassword) const MustChangePasswordTag(),
              Text(
                lastLogin == null
                    ? l10n.staffNeverLoggedIn
                    : l10n.staffLastLogin(TashkentTime.format(lastLogin)),
                style: const TextStyle(fontSize: 12, color: KitColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The member's actions, 6 apart: the rename, and — not for the Admin's own
/// account, which the server refuses to block or reset
/// (`self_block_not_allowed`, `self_reset_not_allowed`) — the password reset
/// and the block or the way back.
class _StaffActions extends ConsumerWidget {
  const _StaffActions({required this.member, required this.busy});

  final StaffMember member;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool blocked = member.status == AccountStatus.blocked;
    final bool own = member.id == ref.watch(staffAccountProvider);

    final List<Widget> buttons = <Widget>[
      PanelActionButton(
        buttonKey: ValueKey<String>('rename-${member.id}'),
        icon: Icons.edit_outlined,
        tooltip: l10n.staffEditName,
        onTap: () => _rename(context, member),
      ),
      if (!own)
        PanelActionButton(
          buttonKey: ValueKey<String>('reset-${member.id}'),
          icon: Icons.lock_reset,
          tooltip: l10n.staffResetPassword,
          onTap: () => _showStaffWindow(
            context,
            (BuildContext context) => _ResetPasswordDialog(member: member),
          ),
        ),
      if (!own && blocked)
        PanelActionButton(
          buttonKey: ValueKey<String>('activate-${member.id}'),
          icon: Icons.lock_open,
          tooltip: l10n.staffActivate,
          onTap: busy
              ? null
              : () => ref
                    .read(staffListActionsProvider.notifier)
                    .activate(member.id),
        ),
      if (!own && !blocked)
        PanelActionButton(
          buttonKey: ValueKey<String>('block-${member.id}'),
          icon: Icons.block,
          tooltip: l10n.staffBlock,
          onTap: busy
              ? null
              : () async {
                  final bool confirmed = await _confirmBlock(context, member);
                  // The confirmation outlives the list when the Admin
                  // moves elsewhere; then there is no block to make.
                  if (!confirmed || !context.mounted) {
                    return;
                  }
                  await ref
                      .read(staffListActionsProvider.notifier)
                      .block(member.id);
                },
        ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < buttons.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 6),
          buttons[i],
        ],
      ],
    );
  }

  static Future<void> _rename(BuildContext context, StaffMember member) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final StaffMember? saved = await showKitDialog<StaffMember>(
      context: context,
      dialogKey: 'rename-dialog',
      title: l10n.staffEditName,
      subtitle:
          '${roleLabel(l10n, member.role)} · ${formatPhone(member.phone)}',
      barrierDismissible: false,
      builder: (BuildContext context) => _RenameForm(member: member),
    );
    if (saved != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).staffSaved)),
      );
    }
  }

  /// Blocking ends every session of the account at once, so it asks first,
  /// with the action itself on the button (`DL-29` (2)).
  static Future<bool> _confirmBlock(
    BuildContext context,
    StaffMember member,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return await showKitDialog<bool>(
          context: context,
          dialogKey: 'block-dialog',
          title: l10n.staffBlockTitle,
          badge: const KitDialogBadge(Icons.block, danger: true),
          builder: (BuildContext context) => _BlockConfirmation(member: member),
        ) ??
        false;
  }
}

/// A field box of the kit: the `field` fill, radius 14, [padding] inside.
class _FieldBox extends StatelessWidget {
  const _FieldBox({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.border,
  });

  final Widget child;
  final EdgeInsets padding;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.field,
        borderRadius: BorderRadius.circular(14),
        border: border,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Whom a block or a reset touches: the name over the role and the phone.
class _MemberBox extends StatelessWidget {
  const _MemberBox(this.member);

  final StaffMember member;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return _FieldBox(
      child: PanelPersonLine(
        name: member.fullName ?? l10n.staffNoName,
        detail:
            '${roleLabel(l10n, member.role)} · ${formatPhone(member.phone)}',
      ),
    );
  }
}

/// Opens a window that stays until its own buttons close it: no scrim tap,
/// no Escape; the window itself holds while an action runs.
Future<void> _showStaffWindow(BuildContext context, WidgetBuilder builder) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: kitDialogBarrier,
    builder: builder,
  );
}

/// What blocking means, and for a Shopper or a Courier how many orders are
/// in their hands now, from the pickers' own count (`DL-45` (1)): a
/// started shopping or a delivery on the way cannot then move to someone
/// else (`DL-62` (3), `DL-67` (5)).
class _BlockConfirmation extends ConsumerWidget {
  const _BlockConfirmation({required this.member});

  final StaffMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final FutureProvider<List<StaffChoice>>? options = switch (member.role) {
      UserRole.shopper => shopperOptionsProvider,
      UserRole.courier => courierOptionsProvider,
      _ => null,
    };
    final String? orders = options == null
        ? null
        : _orders(l10n, ref.watch(options));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _MemberBox(member),
        const SizedBox(height: 14),
        Text(
          l10n.staffBlockSessions,
          style: const TextStyle(fontSize: 13, color: KitColors.ink2),
        ),
        if (orders != null) ...<Widget>[
          const SizedBox(height: 12),
          KitNote(
            icon: StaffRoleChip.iconOf(member.role),
            tone: KitTone.amber,
            text: Text(
              orders,
              key: const ValueKey<String>('block-current-orders'),
            ),
          ),
        ],
        const SizedBox(height: 20),
        kitDialogButtons(
          context: context,
          busy: false,
          destructive: true,
          confirm: l10n.staffBlock,
          confirmIcon: Icons.block,
          confirmKey: const ValueKey<String>('confirm-action'),
          submit: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }

  /// What the confirmation says of the orders in the member's hands: their
  /// count when there are any, and that it is being learned or could not be
  /// learned, so a missing count is never read as none.
  String? _orders(
    AppLocalizations l10n,
    AsyncValue<List<StaffChoice>> choices,
  ) {
    if (choices.hasError) {
      return l10n.staffBlockOrdersUnknown;
    }
    final List<StaffChoice>? list = choices.value;
    if (list == null) {
      return l10n.staffBlockOrdersLoading;
    }
    for (final StaffChoice choice in list) {
      if (choice.id == member.id) {
        final int count = choice.currentAssignmentCount;
        return count > 0 ? l10n.staffBlockCurrentOrders(count) : null;
      }
    }
    return l10n.staffBlockOrdersUnknown;
  }
}

/// A temporary password, shown once in the window that asked for it. It
/// lives in that window alone: when the window closes, nothing in the
/// application holds it any more. The window has no x and only its own
/// button closes it, so a stray click or Escape cannot lose the password
/// before it is copied (`DL-29` (1)).
class _TemporaryPasswordWindow extends StatefulWidget {
  const _TemporaryPasswordWindow(this.issued);

  final IssuedPassword issued;

  @override
  State<_TemporaryPasswordWindow> createState() =>
      _TemporaryPasswordWindowState();
}

class _TemporaryPasswordWindowState extends State<_TemporaryPasswordWindow> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.issued.password));
    if (mounted) {
      setState(() => _copied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final StaffMember staff = widget.issued.staff;

    final Widget password = _FieldBox(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: Border.all(color: KitColors.line, width: 1.5),
      child: SelectableText(
        widget.issued.password,
        key: const ValueKey<String>('temporary-password'),
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
          letterSpacing: 2,
          color: KitColors.ink,
        ),
      ),
    );

    final ButtonStyle copyStyle = _copied
        ? kitOutlined(height: 40).copyWith(
            backgroundColor: const WidgetStatePropertyAll<Color>(
              KitColors.primaryWash,
            ),
          )
        : kitOutlined(height: 40);
    final Widget copy = OutlinedButton.icon(
      key: const ValueKey<String>('copy-password'),
      style: copyStyle,
      onPressed: _copy,
      icon: Icon(_copied ? Icons.check : Icons.content_copy, size: 18),
      label: Text(_copied ? l10n.staffCopied : l10n.staffCopy),
    );

    return PopScope(
      canPop: false,
      child: KitDialogFrame(
        dialogKey: 'password-dialog',
        title: l10n.staffTemporaryPasswordTitle,
        subtitle:
            '${staff.fullName ?? l10n.staffNoName} · ${formatPhone(staff.phone)}',
        badge: const KitDialogBadge(Icons.key_outlined),
        closable: false,
        maxWidth: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (kitLargeText(context)) ...<Widget>[
              password,
              const SizedBox(height: 10),
              copy,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: password),
                  const SizedBox(width: 10),
                  copy,
                ],
              ),
            const SizedBox(height: 14),
            KitNote(
              icon: Icons.warning_amber_rounded,
              tone: KitTone.amber,
              text: Text(l10n.staffTemporaryPasswordWarning),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey<String>('password-done'),
              style: kitFilled(height: 48),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.staffDone),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewStaffDialog extends ConsumerStatefulWidget {
  const _NewStaffDialog();

  @override
  ConsumerState<_NewStaffDialog> createState() => _NewStaffDialogState();
}

class _NewStaffDialogState extends ConsumerState<_NewStaffDialog> {
  /// The refusal the phone field shows itself, where it can be corrected.
  static const String _phoneTakenCode = 'phone_already_active';

  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  UserRole _role = UserRole.shopper;
  Set<String> _rejected = <String>{};
  bool _phoneTaken = false;

  /// The answer of the create, once it came: the window then shows the
  /// password instead of the form.
  IssuedPassword? _issued;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _phoneOf(String text) =>
      phoneFromNationalDigits(text.replaceAll(RegExp(r'\s'), ''));

  Future<void> _submit() async {
    _rejected = <String>{};
    _phoneTaken = false;
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }

    final IssuedPassword? issued = await ref
        .read(newStaffControllerProvider.notifier)
        .create(
          NewStaffMember(
            fullName: _name.text.trim(),
            phone: _phoneOf(_phone.text)!,
            role: _role,
          ),
        );

    if (!mounted) {
      return;
    }
    if (issued != null) {
      setState(() => _issued = issued);
      return;
    }
    final ApiFailure? failure = ref.read(newStaffControllerProvider).failure;
    _rejected = rejectedFields(failure);
    _phoneTaken = failure?.code == _phoneTakenCode;
    _form.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    // Watched while the password shows too, so the controller that answered
    // it stays alive — and holds nothing but its state (`DL-29` (1)).
    final MutationState change = ref.watch(newStaffControllerProvider);
    final IssuedPassword? issued = _issued;
    if (issued != null) {
      return _TemporaryPasswordWindow(issued);
    }

    final AppLocalizations l10n = AppLocalizations.of(context);

    String? rejected(String key) =>
        _rejected.contains(key) ? l10n.fieldRejected : null;

    final ApiFailure? failure = change.failure;

    return PopScope(
      canPop: !change.isBusy,
      child: KitDialogFrame(
        dialogKey: 'staff-dialog',
        title: l10n.staffNew,
        subtitle: l10n.staffNewSubtitle,
        maxWidth: 560,
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              KitLabeledField(
                label: l10n.staffFullName,
                field: TextFormField(
                  key: const ValueKey<String>('field-full_name'),
                  controller: _name,
                  enabled: !change.isBusy,
                  style: panelFieldTextStyle,
                  decoration: panelFieldDecoration(),
                  onChanged: (String _) => _rejected.remove('full_name'),
                  validator: (String? text) =>
                      CatalogFormRules.name(l10n, text ?? '', 120) ??
                      rejected('full_name'),
                ),
              ),
              const SizedBox(height: 16),
              KitLabeledField(
                label: l10n.phoneLabel,
                field: TextFormField(
                  key: const ValueKey<String>('field-phone'),
                  controller: _phone,
                  enabled: !change.isBusy,
                  keyboardType: TextInputType.phone,
                  style: panelFieldTextStyle,
                  decoration: panelFieldDecoration(
                    prefix: phoneCountryCode,
                    hint: l10n.phoneHint,
                  ),
                  onChanged: (String _) {
                    _rejected.remove('phone');
                    _phoneTaken = false;
                  },
                  validator: (String? text) =>
                      (_phoneOf(text ?? '') == null
                          ? l10n.phoneInvalid
                          : null) ??
                      (_phoneTaken ? l10n.errorPhoneAlreadyActive : null) ??
                      rejected('phone'),
                ),
              ),
              const SizedBox(height: 16),
              KitLabeledField(
                label: l10n.staffRole,
                field: StaffRoleTiles(
                  key: const ValueKey<String>('field-role'),
                  selected: _role,
                  onSelected: change.isBusy
                      ? null
                      : (UserRole role) => setState(() => _role = role),
                ),
              ),
              const SizedBox(height: 12),
              KitNote(
                icon: Icons.info_outline,
                tone: KitTone.grey,
                text: Text(l10n.staffRoleFixedNote),
              ),
              if (failure?.code != _phoneTakenCode) FailureMessage(failure),
              const SizedBox(height: 20),
              kitDialogButtons(
                context: context,
                busy: change.isBusy,
                confirm: l10n.saveButton,
                confirmKey: const ValueKey<String>('staff-save'),
                submit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks before a password reset — it ends every session of the account
/// (`DL-29` (2)) — then shows the new password in the same window.
class _ResetPasswordDialog extends ConsumerStatefulWidget {
  const _ResetPasswordDialog({required this.member});

  final StaffMember member;

  @override
  ConsumerState<_ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<_ResetPasswordDialog> {
  IssuedPassword? _issued;

  Future<void> _reset() async {
    final IssuedPassword? issued = await ref
        .read(resetPasswordControllerProvider.notifier)
        .reset(widget.member.id);
    if (mounted && issued != null) {
      setState(() => _issued = issued);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MutationState change = ref.watch(resetPasswordControllerProvider);
    final IssuedPassword? issued = _issued;
    if (issued != null) {
      return _TemporaryPasswordWindow(issued);
    }

    final AppLocalizations l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: !change.isBusy,
      child: KitDialogFrame(
        dialogKey: 'reset-dialog',
        title: l10n.staffResetTitle,
        badge: const KitDialogBadge(Icons.lock_reset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _MemberBox(widget.member),
            const SizedBox(height: 14),
            Text(
              l10n.staffResetExplained,
              style: const TextStyle(fontSize: 13, color: KitColors.ink2),
            ),
            FailureMessage(change.failure),
            const SizedBox(height: 20),
            kitDialogButtons(
              context: context,
              busy: change.isBusy,
              confirm: l10n.staffResetPassword,
              confirmKey: const ValueKey<String>('confirm-action'),
              submit: _reset,
            ),
          ],
        ),
      ),
    );
  }
}

class _RenameForm extends ConsumerStatefulWidget {
  const _RenameForm({required this.member});

  final StaffMember member;

  @override
  ConsumerState<_RenameForm> createState() => _RenameFormState();
}

class _RenameFormState extends ConsumerState<_RenameForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.member.fullName ?? '',
  );
  bool _rejected = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _rejected = false;
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }

    final StaffMember? saved = await ref
        .read(renameStaffControllerProvider.notifier)
        .rename(widget.member, _name.text.trim());

    if (!mounted) {
      return;
    }
    if (saved != null) {
      Navigator.of(context).pop(saved);
      return;
    }
    _rejected = rejectedFields(ref.read(renameStaffControllerProvider).failure)
        .contains('full_name');
    _form.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState change = ref.watch(renameStaffControllerProvider);

    return PopScope(
      canPop: !change.isBusy,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            KitLabeledField(
              label: l10n.staffFullName,
              field: TextFormField(
                key: const ValueKey<String>('field-full_name'),
                controller: _name,
                enabled: !change.isBusy,
                maxLength: 120,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                style: panelFieldTextStyle,
                decoration: panelFieldDecoration(),
                onChanged: (String _) => _rejected = false,
                validator: (String? text) =>
                    CatalogFormRules.name(l10n, text ?? '', 120) ??
                    (_rejected ? l10n.fieldRejected : null),
              ),
            ),
            FailureMessage(change.failure),
            const SizedBox(height: 20),
            kitDialogButtons(
              context: context,
              busy: change.isBusy,
              confirm: l10n.saveButton,
              confirmKey: const ValueKey<String>('rename-save'),
              submit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
