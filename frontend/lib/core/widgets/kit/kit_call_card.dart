import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../formatting/phone_format.dart';
import '../../localization/generated/app_localizations.dart';
import '../../platform/phone_calls.dart';
import '../../theme/kit_colors.dart';
import 'kit_card.dart';
import 'kit_note.dart';

/// A phone as a card that dials it: a [title] over the formatted number and
/// a green call button. When nothing opens the dialer, a snack bar says the
/// number to dial by hand.
class KitCallCard extends ConsumerWidget {
  const KitCallCard({
    required this.title,
    required this.phone,
    this.icon = Icons.person_outline,
    this.tone = KitTone.green,
    super.key,
  });

  final String title;
  final String phone;
  final IconData icon;
  final KitTone tone;

  Future<void> _call(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool opened = await ref.read(phoneCallsProvider).call(phone);
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.callFailed(formatPhone(phone)))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool amber = tone == KitTone.amber;

    return KitCard(
      onTap: () => _call(context, ref),
      semanticLabel: '$title ${formatPhone(phone)}',
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: amber ? KitColors.warningWash : KitColors.primarySoft,
            ),
            child: Icon(
              icon,
              size: 26,
              color: amber ? KitColors.warning : KitColors.primaryDark,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: KitColors.ink,
                  ),
                ),
                Text(
                  formatPhone(phone),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: KitColors.ink2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: KitColors.primary,
            ),
            child: const Icon(Icons.call, size: 24, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
