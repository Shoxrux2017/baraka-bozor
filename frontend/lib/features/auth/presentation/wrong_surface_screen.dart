import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/session/session_state.dart';
import '../domain/app_user.dart';
import 'auth_scaffold.dart';

/// A role on the surface that is not its own (`docs/02-user-roles.md`
/// section 10): the screen names the right one. The only way on is out.
class WrongSurfaceScreen extends ConsumerWidget {
  const WrongSurfaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Surface surface = ref.watch(surfaceProvider);
    final SessionState? session = ref.watch(sessionControllerProvider).value;

    final bool onPhone = surface == Surface.mobile;

    return AuthStatusScaffold(
      wideCard: true,
      icon: onPhone ? Icons.computer : Icons.smartphone,
      title: onPhone ? l10n.wrongSurfaceTitle : l10n.wrongSurfaceWebTitle,
      bodyKey: const ValueKey<String>('wrong-surface-text'),
      body: onPhone ? l10n.wrongSurfaceMobile : l10n.wrongSurfaceWeb,
      button: session is SignedIn
          ? OutlinedButton(
              key: const ValueKey<String>('logout-button'),
              style: AuthScaffold.showsWideCard(context)
                  ? authOutlinedButtonStyle.copyWith(
                      minimumSize: const WidgetStatePropertyAll<Size>(
                        Size(0, 52),
                      ),
                    )
                  : authOutlinedButtonStyle,
              onPressed: () => ref
                  .read(sessionControllerProvider.notifier)
                  .logout(session.activeMode),
              child: Text(l10n.logoutButton),
            )
          : const SizedBox.shrink(),
    );
  }
}
