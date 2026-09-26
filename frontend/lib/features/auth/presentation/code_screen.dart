import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../application/code_login_controller.dart';
import 'auth_scaffold.dart';
import 'code_entry.dart';

/// The Customer's code, after the phone screen sent one. Reached directly,
/// with no code requested, it hands back to the phone screen.
class CodeScreen extends ConsumerWidget {
  const CodeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CodeLoginState state = ref.watch(codeLoginControllerProvider);

    if (!state.hasCode || state.forStaffAccount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(AppPaths.auth);
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return AuthScaffold(
      title: l10n.customerLoginTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CodeEntry(state: state),
          TextButton(
            key: const ValueKey<String>('change-phone-link'),
            onPressed: () {
              ref.read(codeLoginControllerProvider.notifier).changePhone();
              context.go(AppPaths.auth);
            },
            child: Text(l10n.changePhone),
          ),
        ],
      ),
    );
  }
}
