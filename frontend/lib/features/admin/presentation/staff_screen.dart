import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/paged.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/failure_message.dart';
import '../../auth/domain/app_user.dart';
import '../application/admin_providers.dart';
import '../application/admin_staff_controllers.dart';
import '../domain/admin_staff.dart';
import 'catalog_form_rules.dart';
import 'catalog_widgets.dart';

/// The staff roles an Admin creates, in the order the form offers them.
const List<UserRole> staffRoles = <UserRole>[
  UserRole.shopper,
  UserRole.courier,
  UserRole.operator,
  UserRole.manager,
  UserRole.admin,
];

String roleLabel(AppLocalizations l10n, UserRole role) => switch (role) {
  UserRole.shopper => l10n.roleShopper,
  UserRole.courier => l10n.roleCourier,
  UserRole.operator => l10n.roleOperator,
  UserRole.admin => l10n.roleAdmin,
  UserRole.manager => l10n.roleManager,
  UserRole.customer => l10n.shellCustomer,
};

/// The Admin's staff accounts (`docs/09-api-contracts.md` section 43,
/// `docs/04-user-flows.md` section 32): the list with its role and status
/// filters, creation with a temporary password shown once, the name, block
/// and activate, and a password reset.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final StaffQuery query = ref.watch(staffQueryProvider);
    final StaffQueryController queries = ref.read(staffQueryProvider.notifier);
    final AsyncValue<Paged<StaffMember>> page = ref.watch(staffPageProvider);
    final MutationState actions = ref.watch(staffListActionsProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              l10n.adminSectionStaff,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            FilledButton.icon(
              key: const ValueKey<String>('new-staff'),
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.staffNew),
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) => const _NewStaffDialog(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: <Widget>[
            SizedBox(
              width: 240,
              child: DropdownButton<UserRole?>(
                key: const ValueKey<String>('staff-role-filter'),
                isExpanded: true,
                value: query.role,
                items: <DropdownMenuItem<UserRole?>>[
                  DropdownMenuItem<UserRole?>(
                    child: Text(
                      l10n.staffAllRoles,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final UserRole role in staffRoles)
                    DropdownMenuItem<UserRole?>(
                      value: role,
                      child: Text(
                        roleLabel(l10n, role),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: queries.filterByRole,
              ),
            ),
            SizedBox(
              width: 240,
              child: DropdownButton<AccountStatus?>(
                key: const ValueKey<String>('staff-status-filter'),
                isExpanded: true,
                value: query.status,
                items: <DropdownMenuItem<AccountStatus?>>[
                  DropdownMenuItem<AccountStatus?>(
                    child: Text(
                      l10n.staffAllStatuses,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem<AccountStatus?>(
                    value: AccountStatus.active,
                    child: Text(l10n.statusActive),
                  ),
                  DropdownMenuItem<AccountStatus?>(
                    value: AccountStatus.blocked,
                    child: Text(l10n.statusBlocked),
                  ),
                ],
                onChanged: queries.filterByStatus,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FailureMessage(actions.failure),
        page.when(
          skipLoadingOnReload: false,
          data: (Paged<StaffMember> page) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (page.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.catalogEmpty),
                ),
              for (final StaffMember member in page.items)
                _StaffRow(member: member, busy: actions.isBusy),
              PaginationBar(page: page, onPage: queries.goToPage),
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
  }
}

class _StaffRow extends ConsumerWidget {
  const _StaffRow({required this.member, required this.busy});

  /// Below this width the actions go under the account instead of beside
  /// it, which would leave the text a narrow column.
  static const double narrowWidth = 600;

  final StaffMember member;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool blocked = member.status == AccountStatus.blocked;
    final String name = member.fullName ?? l10n.staffNoName;
    final DateTime? lastLogin = member.lastLoginAt;
    // The Admin's own account is not blocked or reset here: the server
    // refuses both (`self_block_not_allowed`, `self_reset_not_allowed`).
    final bool own = member.id == ref.watch(staffAccountProvider);

    final Widget details = Wrap(
      spacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(roleLabel(l10n, member.role)),
        Chip(
          avatar: Icon(
            blocked ? Icons.block : Icons.check_circle_outline,
            size: 18,
          ),
          label: Text(blocked ? l10n.statusBlocked : l10n.statusActive),
          visualDensity: VisualDensity.compact,
        ),
        if (own)
          Chip(
            key: ValueKey<String>('own-${member.id}'),
            avatar: const Icon(Icons.person_outline, size: 18),
            label: Text(l10n.staffYou),
            visualDensity: VisualDensity.compact,
          ),
        if (member.mustChangePassword) Text(l10n.staffMustChangePassword),
        Text(
          lastLogin == null
              ? l10n.staffNeverLoggedIn
              : l10n.staffLastLogin(TashkentTime.format(lastLogin)),
        ),
      ],
    );

    final List<Widget> actions = <Widget>[
      IconButton(
        key: ValueKey<String>('rename-${member.id}'),
        tooltip: l10n.staffEditName,
        icon: const Icon(Icons.edit_outlined),
        onPressed: () => _rename(context, member),
      ),
      if (!own && blocked)
        IconButton(
          key: ValueKey<String>('activate-${member.id}'),
          tooltip: l10n.staffActivate,
          icon: const Icon(Icons.lock_open),
          onPressed: busy
              ? null
              : () => ref
                    .read(staffListActionsProvider.notifier)
                    .activate(member.id),
        ),
      if (!own && !blocked)
        IconButton(
          key: ValueKey<String>('block-${member.id}'),
          tooltip: l10n.staffBlock,
          icon: const Icon(Icons.block),
          onPressed: busy
              ? null
              : () async {
                  final bool confirmed = await _confirmBlock(context, name);
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
      if (!own)
        IconButton(
          key: ValueKey<String>('reset-${member.id}'),
          tooltip: l10n.staffResetPassword,
          icon: const Icon(Icons.password),
          onPressed: () => showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) =>
                _ResetPasswordDialog(member: member),
          ),
        ),
    ];

    return Card(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool narrow = constraints.maxWidth < narrowWidth;
          return ListTile(
            key: ValueKey<String>('staff-${member.id}'),
            title: Text('$name · ${formatPhone(member.phone)}'),
            subtitle: narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      details,
                      Wrap(children: actions),
                    ],
                  )
                : details,
            trailing: narrow ? null : Wrap(children: actions),
          );
        },
      ),
    );
  }

  static Future<void> _rename(BuildContext context, StaffMember member) async {
    final StaffMember? saved = await showDialog<StaffMember>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _RenameDialog(member: member),
    );
    if (saved != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).staffSaved)),
      );
    }
  }

  /// Blocking ends every session of the account at once, so it asks first,
  /// with the action itself on the button (`DL-29` (2)).
  static Future<bool> _confirmBlock(BuildContext context, String name) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            scrollable: true,
            content: Text(l10n.staffBlockConfirm(name)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancelButton),
              ),
              FilledButton(
                key: const ValueKey<String>('confirm-action'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.staffBlock),
              ),
            ],
          ),
        ) ??
        false;
  }
}

/// A temporary password, shown once in the dialog that asked for it. It
/// lives in that dialog alone: when the dialog closes, nothing in the
/// application holds it any more. Only its own button closes it, so a stray
/// click or Escape cannot lose the password before it is copied
/// (`DL-29` (1)).
class _TemporaryPasswordDialog extends StatelessWidget {
  const _TemporaryPasswordDialog(this.issued);

  final IssuedPassword issued;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        scrollable: true,
        title: Text(l10n.staffTemporaryPasswordTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${issued.staff.fullName ?? l10n.staffNoName} · '
              '${formatPhone(issued.staff.phone)}',
            ),
            const SizedBox(height: 16),
            SelectableText(
              issued.password,
              key: const ValueKey<String>('temporary-password'),
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontFamily: 'monospace', letterSpacing: 2),
            ),
            const SizedBox(height: 16),
            Text(l10n.staffTemporaryPasswordWarning),
          ],
        ),
        actions: <Widget>[
          TextButton.icon(
            key: const ValueKey<String>('copy-password'),
            icon: const Icon(Icons.copy),
            label: Text(l10n.staffCopy),
            onPressed: () async {
              final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
                context,
              );
              await Clipboard.setData(ClipboardData(text: issued.password));
              messenger.showSnackBar(SnackBar(content: Text(l10n.staffCopied)));
            },
          ),
          FilledButton(
            key: const ValueKey<String>('password-done'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.staffDone),
          ),
        ],
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
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  UserRole _role = UserRole.shopper;
  Set<String> _rejected = <String>{};

  /// The answer of the create, once it came: the dialog then shows the
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
    _rejected = rejectedFields(ref.read(newStaffControllerProvider).failure);
    _form.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    // Watched while the password shows too, so the controller that answered
    // it stays alive — and holds nothing but its state (`DL-29` (1)).
    final MutationState change = ref.watch(newStaffControllerProvider);
    final IssuedPassword? issued = _issued;
    if (issued != null) {
      return _TemporaryPasswordDialog(issued);
    }

    final AppLocalizations l10n = AppLocalizations.of(context);

    String? rejected(String key) =>
        _rejected.contains(key) ? l10n.fieldRejected : null;

    return PopScope(
      canPop: !change.isBusy,
      child: AlertDialog(
        title: Text(l10n.staffNew),
        content: SizedBox(
          width: 480,
          child: Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    key: const ValueKey<String>('field-full_name'),
                    controller: _name,
                    enabled: !change.isBusy,
                    decoration: InputDecoration(
                      labelText: l10n.staffFullName,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (String _) => _rejected.remove('full_name'),
                    validator: (String? text) =>
                        CatalogFormRules.name(l10n, text ?? '', 120) ??
                        rejected('full_name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey<String>('field-phone'),
                    controller: _phone,
                    enabled: !change.isBusy,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: l10n.phoneLabel,
                      prefixText: '$phoneCountryCode ',
                      hintText: l10n.phoneHint,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (String _) => _rejected.remove('phone'),
                    validator: (String? text) =>
                        (_phoneOf(text ?? '') == null
                            ? l10n.phoneInvalid
                            : null) ??
                        rejected('phone'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UserRole>(
                    key: const ValueKey<String>('field-role'),
                    isExpanded: true,
                    initialValue: _role,
                    decoration: InputDecoration(
                      labelText: l10n.staffRole,
                      border: const OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<UserRole>>[
                      for (final UserRole role in staffRoles)
                        DropdownMenuItem<UserRole>(
                          value: role,
                          child: Text(
                            roleLabel(l10n, role),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: change.isBusy
                        ? null
                        : (UserRole? role) =>
                              setState(() => _role = role ?? _role),
                  ),
                  FailureMessage(change.failure),
                ],
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: change.isBusy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: const ValueKey<String>('staff-save'),
            onPressed: change.isBusy ? null : _submit,
            child: Text(l10n.saveButton),
          ),
        ],
      ),
    );
  }
}

/// Asks before a password reset — it ends every session of the account
/// (`DL-29` (2)) — then shows the new password in the same dialog.
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
      return _TemporaryPasswordDialog(issued);
    }

    final AppLocalizations l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: !change.isBusy,
      child: AlertDialog(
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.staffResetConfirm(
                widget.member.fullName ?? l10n.staffNoName,
              ),
            ),
            FailureMessage(change.failure),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: change.isBusy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: const ValueKey<String>('confirm-action'),
            onPressed: change.isBusy ? null : _reset,
            child: Text(l10n.staffResetPassword),
          ),
        ],
      ),
    );
  }
}

class _RenameDialog extends ConsumerStatefulWidget {
  const _RenameDialog({required this.member});

  final StaffMember member;

  @override
  ConsumerState<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends ConsumerState<_RenameDialog> {
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
      child: AlertDialog(
        scrollable: true,
        title: Text(l10n.staffEditName),
        content: SizedBox(
          width: 480,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  key: const ValueKey<String>('field-full_name'),
                  controller: _name,
                  enabled: !change.isBusy,
                  decoration: InputDecoration(
                    labelText: l10n.staffFullName,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (String _) => _rejected = false,
                  validator: (String? text) =>
                      CatalogFormRules.name(l10n, text ?? '', 120) ??
                      (_rejected ? l10n.fieldRejected : null),
                ),
                FailureMessage(change.failure),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: change.isBusy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: const ValueKey<String>('rename-save'),
            onPressed: change.isBusy ? null : _submit,
            child: Text(l10n.saveButton),
          ),
        ],
      ),
    );
  }
}
