import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../auth/presentation/lock_message.dart';
import '../application/account_deletion_controller.dart';
import '../domain/account_deletion.dart';

/// How the confirm sheet ended when it closed by itself.
enum _Answer { codeSent, unfinished }

/// Sheet 36: says what is erased and kept, then asks for the code. A sent
/// code opens the code screen; an unfinished order opens sheet 36б.
Future<void> showDeleteAccountSheet(BuildContext context) async {
  final ProviderContainer container = ProviderScope.containerOf(context);
  container.read(accountDeletionControllerProvider.notifier).reset();

  final _Answer? answer = await showModalBottomSheet<_Answer>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext sheet) => const _DeleteAccountSheet(),
  );
  if (!context.mounted || answer == null) {
    return;
  }

  switch (answer) {
    case _Answer.codeSent:
      await context.push<void>(AppPaths.customerDeleteAccount);
    case _Answer.unfinished:
      final UnfinishedOrder? order = container
          .read(accountDeletionControllerProvider)
          .unfinished;
      if (order != null) {
        await showUnfinishedOrderSheet(context, order);
      }
  }
}

/// Sheet 36б: an order that is not finished stops the deletion. "Понятно"
/// closes it — and, with [leaveScreen], the screen behind it; "К заказу"
/// opens the order.
Future<void> showUnfinishedOrderSheet(
  BuildContext context,
  UnfinishedOrder order, {
  bool leaveScreen = false,
}) async {
  final bool? toOrder = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext sheet) => _UnfinishedOrderSheet(order: order),
  );
  if (!context.mounted) {
    return;
  }
  if (toOrder ?? false) {
    await context.push<void>(AppPaths.customerOrder(order.id));
  } else if (leaveScreen) {
    context.pop();
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.sheetKey,
    required this.wash,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  final Key sheetKey;
  final Color wash;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: sheetKey,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: KitColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: wash, shape: BoxShape.circle),
              child: Icon(icon, size: 28, color: iconColor),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// Two sheet buttons side by side, one above the other when the text is
/// large.
class _SheetButtons extends StatelessWidget {
  const _SheetButtons({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(14) > 18) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[right, const SizedBox(height: 10), left],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

const TextStyle _buttonText = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
);

ButtonStyle _outlined() => OutlinedButton.styleFrom(
  foregroundColor: KitColors.ink,
  side: const BorderSide(color: KitColors.line),
  minimumSize: const Size.fromHeight(54),
  padding: const EdgeInsets.symmetric(horizontal: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);

ButtonStyle _filled(Color color) => FilledButton.styleFrom(
  backgroundColor: color,
  foregroundColor: Colors.white,
  disabledBackgroundColor: color.withValues(alpha: 0.5),
  disabledForegroundColor: Colors.white,
  minimumSize: const Size.fromHeight(54),
  padding: const EdgeInsets.symmetric(horizontal: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);

class _DeleteAccountSheet extends ConsumerWidget {
  const _DeleteAccountSheet();

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final AccountDeletionController controller = ref.read(
      accountDeletionControllerProvider.notifier,
    );
    final bool sent = await controller.requestCode();
    if (!context.mounted) {
      return;
    }
    final bool unfinished =
        ref.read(accountDeletionControllerProvider).unfinished != null;
    if (sent) {
      Navigator.of(context).pop(_Answer.codeSent);
    } else if (unfinished) {
      Navigator.of(context).pop(_Answer.unfinished);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AccountDeletionState state = ref.watch(
      accountDeletionControllerProvider,
    );

    return PopScope(
      canPop: !state.busy,
      child: _SheetFrame(
        sheetKey: const ValueKey<String>('delete-account-sheet'),
        wash: KitColors.dangerWash,
        icon: Icons.delete,
        iconColor: KitColors.danger,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              l10n.deleteAccountTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Heading(l10n.deleteErasedHeading),
          _Line(
            icon: Icons.close,
            color: KitColors.danger,
            text: l10n.deleteErasedName,
          ),
          _Line(
            icon: Icons.close,
            color: KitColors.danger,
            text: l10n.deleteErasedAddresses,
          ),
          _Line(
            icon: Icons.close,
            color: KitColors.danger,
            text: l10n.deleteErasedFavorites,
          ),
          const SizedBox(height: 16),
          _Heading(l10n.deleteKeptHeading),
          _Line(
            icon: Icons.check,
            color: KitColors.primaryDark,
            text: l10n.deleteKeptOrders,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KitColors.field,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l10n.deleteNote,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: KitColors.ink2,
              ),
            ),
          ),
          FailureMessage(state.failure),
          LockMessage(lockedSeconds: state.lockedSeconds),
          const SizedBox(height: 20),
          _SheetButtons(
            left: OutlinedButton(
              key: const ValueKey<String>('delete-cancel'),
              style: _outlined(),
              onPressed: state.busy ? null : () => Navigator.of(context).pop(),
              child: Text(
                l10n.cancelButton,
                textAlign: TextAlign.center,
                style: _buttonText,
              ),
            ),
            right: FilledButton(
              key: const ValueKey<String>('delete-confirm'),
              style: _filled(KitColors.danger),
              onPressed: state.busy || state.locked
                  ? null
                  : () => _confirm(context, ref),
              child: state.busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      l10n.deleteConfirm,
                      textAlign: TextAlign.center,
                      style: _buttonText,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: KitColors.ink,
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.3,
                color: KitColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnfinishedOrderSheet extends StatelessWidget {
  const _UnfinishedOrderSheet({required this.order});

  final UnfinishedOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return _SheetFrame(
      sheetKey: const ValueKey<String>('delete-unfinished-sheet'),
      wash: KitColors.warningWash,
      icon: Icons.hourglass_top,
      iconColor: KitColors.warning,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            l10n.deleteBlockedTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: KitColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.deleteBlockedBody(order.number),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: KitColors.ink2,
          ),
        ),
        const SizedBox(height: 20),
        _SheetButtons(
          left: OutlinedButton(
            key: const ValueKey<String>('delete-understood'),
            style: _outlined(),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              l10n.understoodButton,
              textAlign: TextAlign.center,
              style: _buttonText,
            ),
          ),
          right: FilledButton(
            key: const ValueKey<String>('delete-to-order'),
            style: _filled(KitColors.primary),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.toOrderButton,
              textAlign: TextAlign.center,
              style: _buttonText,
            ),
          ),
        ),
      ],
    );
  }
}
