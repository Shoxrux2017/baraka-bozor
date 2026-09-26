import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/session_state.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/code_login_controller.dart';
import 'auth_scaffold.dart';
import 'code_entry.dart';

/// Customer mode from the staff interface (`docs/02-user-roles.md`
/// section 10): the staff shell asks for a code to the staff account's own
/// phone and opens this screen; verifying the code opens the customer
/// session. The router admits this screen only for a Shopper or Courier
/// without one.
class CustomerModeScreen extends ConsumerWidget {
  const CustomerModeScreen({super.key});

  void _cancel(BuildContext context, WidgetRef ref) {
    ref.read(codeLoginControllerProvider.notifier).reset();
    final SessionState? session = ref.read(sessionControllerProvider).value;
    context.go(
      session is SignedIn
          ? AppPaths.areaOf(session.activeUser.role)
          : AppPaths.auth,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CodeLoginState state = ref.watch(codeLoginControllerProvider);
    final bool codeForStaff = state.hasCode && state.forStaffAccount;

    return AuthScaffold(
      title: l10n.customerModeLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.customerModeIntro),
          const SizedBox(height: 16),
          if (codeForStaff)
            CodeEntry(state: state)
          else if (state.busy)
            const Center(child: CircularProgressIndicator())
          else ...<Widget>[
            // Reached without a code on its way: a direct entry, or a
            // request that failed. The failure, and a way to ask again.
            FailureMessage(state.failure),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey<String>('request-code-button'),
              onPressed: () => ref
                  .read(codeLoginControllerProvider.notifier)
                  .requestCodeForStaffAccount(),
              child: Text(l10n.requestCodeButton),
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            key: const ValueKey<String>('cancel-button'),
            onPressed: state.busy ? null : () => _cancel(context, ref),
            child: Text(l10n.cancelButton),
          ),
        ],
      ),
    );
  }
}
