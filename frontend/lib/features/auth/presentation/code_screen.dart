import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../application/code_login_controller.dart';
import 'auth_scaffold.dart';
import 'code_entry.dart';

/// The Customer's code, after the phone page sent one (screen 04 of
/// `kit/01-vhod`). It is pushed over the phone page: system back, the arrow
/// and «Изменить» all pop it and the number stays typed (`DL-139`). Reached
/// directly, with no code requested, it hands back to the phone page.
class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({super.key});

  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<CodeScreen> {
  final GlobalKey _buttonKey = GlobalKey();

  /// The last state that had a code. A page that is leaving draws it, so the
  /// flow being reset under it does not change what slides away.
  CodeLoginState? _shown;

  void _back() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CodeLoginState live = ref.watch(codeLoginControllerProvider);
    final bool current = ModalRoute.isCurrentOf(context) ?? true;
    if (live.hasCode) {
      _shown = live;
    }
    final CodeLoginState? shown = _shown;

    if (!live.hasCode && current) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          context.go(AppPaths.auth);
        }
      });
    }
    if (shown == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return PopScope(
      canPop: !live.busy && !live.accepted,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          ref.read(codeLoginControllerProvider.notifier).changePhone();
        }
      },
      child: AuthScaffold(
        title: l10n.codeTitle,
        card: true,
        onBack: _back,
        backLabel: l10n.codeBackSpoken,
        keepVisible: _buttonKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Header(state: shown, onChange: _back),
            CodeEntry(state: shown, buttonKey: _buttonKey),
          ],
        ),
      ),
    );
  }
}

/// «Отправили код … на номер», the number big, and «Изменить».
class _Header extends StatelessWidget {
  const _Header({required this.state, required this.onChange});

  final CodeLoginState state;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String lead = switch (RequestedCodeChannel.of(
      state.requested?.channel,
    )) {
      RequestedCodeChannel.telegram => l10n.codeSentLead,
      RequestedCodeChannel.sms => l10n.codeSentLeadSms,
      RequestedCodeChannel.other => l10n.codeSentLeadOther,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          lead,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: KitColors.muted),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              formatPhone(state.phone ?? ''),
              key: const ValueKey<String>('code-phone'),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
            TextButton(
              key: const ValueKey<String>('code-change-phone'),
              onPressed: onChange,
              style: TextButton.styleFrom(
                foregroundColor: KitColors.primaryDark,
                minimumSize: const Size(0, 44),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Semantics(
                label: l10n.changePhone,
                excludeSemantics: true,
                child: Text(l10n.editButton),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
