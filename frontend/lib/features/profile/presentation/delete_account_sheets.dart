import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/session_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/retry_strip.dart';
import '../../../core/widgets/sheet_hold.dart';
import '../../auth/presentation/auth_notice.dart';
import '../../auth/presentation/code_entry.dart';
import '../../auth/presentation/lock_message.dart';
import '../../auth/presentation/telegram_mark.dart';
import '../application/account_deletion_controller.dart';
import '../domain/account_deletion.dart';

/// How the sheet ended when it closed by itself: a code was sent, or the
/// Customer chose to open the order that blocks the deletion.
final class _SheetResult {
  const _SheetResult.codeSent() : orderId = null;
  const _SheetResult.order(String this.orderId);

  final String? orderId;
}

Future<_SheetResult?> _present(
  BuildContext context, {
  UnfinishedOrder? blocked,
}) {
  return showModalBottomSheet<_SheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (BuildContext sheet) => _DeletionSheet(blocked: blocked),
  );
}

/// The sheet that says what is erased and kept, then asks for the code
/// (`DL-140`). A sent code opens the code screen; an unfinished order turns
/// the same sheet into its blocked face, whose card opens that order.
Future<void> showDeleteAccountSheet(BuildContext context) async {
  final ProviderContainer container = ProviderScope.containerOf(context);
  container.read(accountDeletionControllerProvider.notifier).reset();

  final _SheetResult? result = await _present(context);
  if (!context.mounted || result == null) {
    return;
  }
  final String? orderId = result.orderId;
  if (orderId == null) {
    await context.push<void>(AppPaths.customerDeleteAccount);
  } else {
    await context.push<void>(AppPaths.customerOrder(orderId));
  }
}

/// The blocked face of the sheet on its own: an order that is not finished
/// stops the deletion. "Понятно" closes it — and, with [leaveScreen], the
/// screen behind it; "К заказу" and the card open the order.
Future<void> showUnfinishedOrderSheet(
  BuildContext context,
  UnfinishedOrder order, {
  bool leaveScreen = false,
}) async {
  final _SheetResult? result = await _present(context, blocked: order);
  if (!context.mounted) {
    return;
  }
  final String? orderId = result?.orderId;
  if (orderId != null) {
    await context.push<void>(AppPaths.customerOrder(orderId));
  } else if (leaveScreen) {
    context.pop();
  }
}

const Cubic _settle = Cubic(0.2, 0.8, 0.2, 1);

const TextStyle _buttonText = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
);

class _DeletionSheet extends ConsumerStatefulWidget {
  const _DeletionSheet({this.blocked});

  /// Set when the sheet opens already blocked; otherwise the controller's
  /// state decides which face shows.
  final UnfinishedOrder? blocked;

  @override
  ConsumerState<_DeletionSheet> createState() => _DeletionSheetState();
}

class _DeletionSheetState extends ConsumerState<_DeletionSheet> {
  bool _watching = false;

  /// The route started to close: what is on screen stays as it is while the
  /// sheet slides away, even though the flow was reset.
  bool _closing = false;

  /// A sent code keeps the flow's state for the code screen.
  bool _keepFlow = false;

  Widget? _frozen;

  @override
  void initState() {
    super.initState();
    final UnfinishedOrder? blocked = widget.blocked;
    if (blocked != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _announceBlocked(blocked);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_watching || widget.blocked != null) {
      return;
    }
    _watching = true;
    final AccountDeletionController controller = ref.read(
      accountDeletionControllerProvider.notifier,
    );
    // Closing the sheet by any road drops an answer still on its way.
    ModalRoute.of(context)?.popped.then((_) {
      _closing = true;
      if (!_keepFlow) {
        controller.reset();
      }
    });
  }

  void _announceBlocked(UnfinishedOrder order) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    announce(
      context,
      '${l10n.deleteBlockedTitle}. ${l10n.deleteBlockedBody(order.number)}',
    );
  }

  String _phone() =>
      ref.read(
        sessionControllerProvider.select((AsyncValue<SessionState> session) {
          final SessionState? current = session.value;
          return current is SignedIn ? current.customerUser?.phone : null;
        }),
      ) ??
      '';

  Future<void> _send() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String phone = _phone();
    final AccountDeletionController controller = ref.read(
      accountDeletionControllerProvider.notifier,
    );
    announce(context, l10n.sendingCode);
    final bool sent = await controller.requestCode();
    if (!sent || !mounted || _closing) {
      return;
    }
    announce(
      context,
      codeSentSpoken(
        l10n,
        phone: phone,
        channel: ref.read(accountDeletionControllerProvider).requested?.channel,
      ),
    );
    _keepFlow = true;
    Navigator.of(context).pop(const _SheetResult.codeSent());
  }

  void _onAction(AuthNoticeAction action) {
    switch (action) {
      case AuthNoticeAction.retry || AuthNoticeAction.newCode:
        _send();
      case AuthNoticeAction.otherNumber || AuthNoticeAction.changeNumber:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget? frozen = _frozen;
    if (_closing && frozen != null) {
      return frozen;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AccountDeletionState state = ref.watch(
      accountDeletionControllerProvider,
    );
    ref.listen<AccountDeletionState>(accountDeletionControllerProvider, (
      AccountDeletionState? before,
      AccountDeletionState next,
    ) {
      final UnfinishedOrder? order = next.unfinished;
      if (before?.unfinished == null && order != null) {
        _announceBlocked(order);
      }
      final bool wasOffline =
          before != null &&
          before.offline &&
          before.failedAction == DeletionAction.request;
      if (!wasOffline &&
          next.offline &&
          next.failedAction == DeletionAction.request) {
        announce(context, l10n.deleteSendOffline);
      }
    });

    final UnfinishedOrder? order = widget.blocked ?? state.unfinished;
    final String phone = _phone();
    final bool reduced = MediaQuery.disableAnimationsOf(context);

    final Widget face = order != null
        ? _BlockedFace(
            key: const ValueKey<String>('delete-unfinished-sheet'),
            order: order,
          )
        : _IdleFace(
            key: const ValueKey<String>('delete-account-sheet'),
            state: state,
            phone: phone,
            onSend: _send,
            onAction: _onAction,
          );

    return _frozen = SheetHold(
      holding: state.running == DeletionAction.request,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Outside the scroll view, so the sheet always drags by its top.
            const _Grabber(),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  20 + MediaQuery.paddingOf(context).bottom,
                ),
                child: AnimatedSize(
                  duration: reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  curve: _settle,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: reduced ? 200 : 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeOut,
                    layoutBuilder: (Widget? current, List<Widget> previous) =>
                        Stack(
                          alignment: Alignment.topCenter,
                          children: <Widget>[
                            for (final Widget old in previous)
                              Positioned(top: 0, left: 0, right: 0, child: old),
                            ?current,
                          ],
                        ),
                    child: face,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: KitColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({
    required this.wash,
    required this.icon,
    required this.color,
  });

  final Color wash;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: wash, shape: BoxShape.circle),
        child: Icon(icon, size: 28, color: color),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: KitColors.ink,
        ),
      ),
    );
  }
}

class _IdleFace extends StatelessWidget {
  const _IdleFace({
    required this.state,
    required this.phone,
    required this.onSend,
    required this.onAction,
    super.key,
  });

  final AccountDeletionState state;
  final String phone;
  final VoidCallback onSend;
  final ValueChanged<AuthNoticeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool sending = state.running == DeletionAction.request;
    final bool offline =
        state.offline && state.failedAction == DeletionAction.request;
    final bool refused =
        state.failure != null && !state.offline && !state.locked;

    return ColoredBox(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _IconCircle(
            wash: KitColors.dangerWash,
            icon: Icons.delete,
            color: KitColors.danger,
          ),
          const SizedBox(height: 16),
          _Title(l10n.deleteAccountTitle),
          const SizedBox(height: 6),
          Text(
            l10n.deleteSubtitle,
            key: const ValueKey<String>('delete-subtitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: KitColors.ink2,
            ),
          ),
          const SizedBox(height: 14),
          _Group(
            groupKey: const ValueKey<String>('delete-erased-group'),
            caption: l10n.deleteErasedHeading,
            spoken: l10n.deleteErasedSpoken,
            rows: <(IconData, String)>[
              (Icons.person, l10n.deleteErasedName),
              (Icons.location_on, l10n.deleteErasedAddresses),
              (Icons.favorite, l10n.deleteErasedFavorites),
              (Icons.shopping_basket, l10n.deleteErasedCart),
            ],
          ),
          const SizedBox(height: 14),
          _Group(
            groupKey: const ValueKey<String>('delete-kept-group'),
            caption: l10n.deleteKeptHeading,
            spoken: l10n.deleteKeptSpoken,
            rows: <(IconData, String)>[
              (Icons.receipt_long, l10n.deleteKeptOrders),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.deleteAgain,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: KitColors.muted),
          ),
          const SizedBox(height: 16),
          _TelegramLine(phone: phone),
          if (offline)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: RetryStrip(
                message: l10n.deleteSendOffline,
                onRetry: onSend,
                stripKey: const ValueKey<String>('delete-send-strip'),
              ),
            ),
          if (refused)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: AuthNotice(
                view: authNoticeOf(
                  l10n,
                  state.failure!,
                  phone: phone,
                  place: AuthNoticePlace.deletion,
                ),
                onAction: onAction,
              ),
            ),
          if (state.locked)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: LockMessage(lockedSeconds: state.lockedSeconds),
            ),
          SizedBox(height: offline ? 2 : 14),
          FilledButton(
            key: const ValueKey<String>('delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: KitColors.dangerWash,
              foregroundColor: KitColors.danger,
              disabledBackgroundColor: KitColors.dangerWash,
              disabledForegroundColor: sending
                  ? KitColors.danger
                  : KitColors.danger.withValues(alpha: 0.5),
              minimumSize: const Size.fromHeight(54),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: state.busy || state.locked ? null : onSend,
            child: sending
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: KitColors.danger,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          l10n.sendingCode,
                          textAlign: TextAlign.center,
                          style: _buttonText,
                        ),
                      ),
                    ],
                  )
                : Text(
                    l10n.deleteGetCode,
                    textAlign: TextAlign.center,
                    style: _buttonText,
                  ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            key: const ValueKey<String>('delete-cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: KitColors.ink,
              backgroundColor: Colors.white,
              side: const BorderSide(color: KitColors.outline),
              minimumSize: const Size.fromHeight(54),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              l10n.deleteKeep,
              textAlign: TextAlign.center,
              style: _buttonText.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// A grey group of things: a caption and rows, read as one phrase.
class _Group extends StatelessWidget {
  const _Group({
    required this.groupKey,
    required this.caption,
    required this.spoken,
    required this.rows,
  });

  final Key groupKey;
  final String caption;
  final String spoken;
  final List<(IconData, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: groupKey,
      container: true,
      label: spoken,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KitColors.page,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 2),
                child: Text(
                  caption,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: KitColors.muted,
                  ),
                ),
              ),
              for (int i = 0; i < rows.length; i++) ...<Widget>[
                if (i > 0) Container(height: 1, color: KitColors.line),
                _GroupRow(icon: rows[i].$1, text: rows[i].$2),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 38),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: KitColors.ink2),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: KitColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the code will go, with the phone unbroken and bold.
class _TelegramLine extends StatelessWidget {
  const _TelegramLine({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String shown = formatPhone(phone).replaceAll(' ', ' ');
    final String text = l10n.deleteCodeWillCome(shown);
    final int at = text.indexOf(shown);
    const TextStyle base = TextStyle(
      fontSize: 13,
      height: 1.4,
      color: KitColors.ink2,
    );

    return Row(
      key: const ValueKey<String>('delete-telegram-line'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const TelegramMark(size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text.rich(
            TextSpan(
              style: base,
              children: <InlineSpan>[
                TextSpan(text: text.substring(0, at)),
                TextSpan(
                  text: shown,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: text.substring(at + shown.length)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BlockedFace extends StatelessWidget {
  const _BlockedFace({required this.order, super.key});

  final UnfinishedOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final OrderStatus? status = order.status;
    final List<String> facts = <String>[
      if (status != null) OrderLabels.customerStatus(l10n, status),
      if (order.itemCount > 0) l10n.orderItemCount(order.itemCount),
    ];

    return ColoredBox(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _IconCircle(
            wash: KitColors.warningWash,
            icon: Icons.hourglass_top,
            color: KitColors.warning,
          ),
          const SizedBox(height: 16),
          _Title(l10n.deleteBlockedTitle),
          const SizedBox(height: 8),
          Text(
            l10n.deleteBlockedBody(order.number),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: KitColors.ink2,
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: KitColors.page,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: const ValueKey<String>('delete-order-card'),
              borderRadius: BorderRadius.circular(14),
              onTap: () =>
                  Navigator.of(context).pop(_SheetResult.order(order.id)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.receipt_long,
                        size: 22,
                        color: KitColors.ink2,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              l10n.customerOrderTitle(order.number),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: KitColors.ink,
                              ),
                            ),
                            if (facts.isNotEmpty)
                              Text(
                                facts.join(' · '),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: KitColors.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right,
                        size: 22,
                        color: KitColors.ink2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SheetButtons(
            left: OutlinedButton(
              key: const ValueKey<String>('delete-understood'),
              style: OutlinedButton.styleFrom(
                foregroundColor: KitColors.ink,
                side: const BorderSide(color: KitColors.line),
                minimumSize: const Size.fromHeight(54),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l10n.understoodButton,
                textAlign: TextAlign.center,
                style: _buttonText,
              ),
            ),
            right: FilledButton(
              key: const ValueKey<String>('delete-to-order'),
              style: FilledButton.styleFrom(
                backgroundColor: KitColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () =>
                  Navigator.of(context).pop(_SheetResult.order(order.id)),
              child: Text(
                l10n.toOrderButton,
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

/// Two sheet buttons side by side, one above the other when the text is
/// large (`DL-126`).
class _SheetButtons extends StatelessWidget {
  const _SheetButtons({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (textScaleAt(MediaQuery.textScalerOf(context), 14) > 1.3) {
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
