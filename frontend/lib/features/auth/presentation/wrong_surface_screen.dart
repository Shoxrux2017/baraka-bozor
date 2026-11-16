import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/session/session_state.dart';
import '../../../core/widgets/submit_button.dart';
import '../domain/app_user.dart';
import 'auth_scaffold.dart';

/// A role on the surface that is not its own (`docs/02-user-roles.md`
/// section 10): the screen says who signed in, where that role works and the
/// way on (`DL-136`). On a phone a staff session of the panel's roles is told
/// that shopping works here and offered «Войти как покупатель»; in a browser
/// the person is offered another account. Both buttons end the active session.
class WrongSurfaceScreen extends ConsumerWidget {
  const WrongSurfaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Surface surface = ref.watch(surfaceProvider);
    final SessionState? session = ref.watch(sessionControllerProvider).value;

    final bool onPhone = surface == Surface.mobile;
    final AppUser? user = session is SignedIn ? session.activeUser : null;
    final String role = user?.role.code ?? '';
    final String name = user?.fullName?.trim() ?? '';

    final String body = onPhone
        ? (name.isEmpty
              ? l10n.wrongSurfacePanelWhoNameless(role)
              : l10n.wrongSurfacePanelWho(role, name))
        : (name.isEmpty
              ? l10n.wrongSurfaceAppWhoNameless(role)
              : l10n.wrongSurfaceAppWho(role, name));

    return AuthStatusScaffold(
      wideCard: true,
      icon: onPhone ? Icons.computer : Icons.smartphone,
      title: onPhone ? l10n.wrongSurfacePanelTitle : l10n.wrongSurfaceAppTitle,
      bodyKey: const ValueKey<String>('wrong-surface-text'),
      body: body,
      note: onPhone ? l10n.wrongSurfacePanelShop : null,
      button: session is SignedIn
          ? SubmitButton(
              face: SubmitFace.ready,
              label: onPhone
                  ? l10n.wrongSurfaceSignInCustomer
                  : l10n.wrongSurfaceOtherAccount,
              buttonKey: const ValueKey<String>('wrong-surface-button'),
              onPressed: () => ref
                  .read(sessionControllerProvider.notifier)
                  .logout(session.activeMode),
            )
          : const SizedBox.shrink(),
    );
  }
}
