import 'package:flutter/material.dart';

import '../../../core/layout/text_width.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';

/// The sheet «Выйти из аккаунта?» (kit drawing 32, `DL-135`): says how to come
/// back and what stays. Completes with `true` only from «Выйти»; «Отмена», a
/// tap outside and a swipe down all give `false`. [phone] is shown formatted;
/// [staffStays] adds that the staff mode remains on the phone.
Future<bool> showLogoutSheet(
  BuildContext context, {
  required String phone,
  required bool staffStays,
}) async {
  final bool? confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext sheet) =>
        _LogoutSheet(phone: phone, staffStays: staffStays),
  );
  return confirmed ?? false;
}

class _LogoutSheet extends StatelessWidget {
  const _LogoutSheet({required this.phone, required this.staffStays});

  final String phone;
  final bool staffStays;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool large = textScaleAt(MediaQuery.textScalerOf(context), 16) > 1.3;

    final Widget cancel = OutlinedButton(
      key: const ValueKey<String>('logout-cancel'),
      style: OutlinedButton.styleFrom(
        foregroundColor: KitColors.ink,
        backgroundColor: Colors.white,
        side: const BorderSide(color: KitColors.outline),
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: _buttonText,
      ),
      onPressed: () => Navigator.of(context).pop(false),
      child: Text(l10n.cancelButton),
    );
    final Widget confirm = FilledButton(
      key: const ValueKey<String>('logout-confirm'),
      style: FilledButton.styleFrom(
        backgroundColor: KitColors.danger,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: _buttonText,
      ),
      onPressed: () => Navigator.of(context).pop(true),
      child: Text(l10n.logoutButton),
    );

    return SingleChildScrollView(
      key: const ValueKey<String>('logout-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: KitColors.fieldEdge,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: KitColors.dangerWash,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout,
                size: 28,
                color: KitColors.danger,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              l10n.logoutTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.logoutBody(phone),
            textAlign: TextAlign.center,
            style: _body,
          ),
          if (staffStays)
            Text(
              l10n.logoutStaffStays,
              textAlign: TextAlign.center,
              style: _body,
            ),
          const SizedBox(height: 22),
          if (large)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[confirm, const SizedBox(height: 12), cancel],
            )
          else
            Row(
              children: <Widget>[
                Expanded(child: cancel),
                const SizedBox(width: 12),
                Expanded(child: confirm),
              ],
            ),
        ],
      ),
    );
  }
}

const TextStyle _body = TextStyle(
  fontSize: 14,
  height: 1.5,
  color: KitColors.ink2,
);

const TextStyle _buttonText = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
);
