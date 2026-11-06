import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/session_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/customer_tab_bar.dart';
import '../application/profile_controllers.dart';
import '../domain/profile.dart';
import 'profile_header.dart';
import 'profile_rows.dart';

/// The Customer's profile tab (`docs/03-features.md` section 3, kit drawings
/// 32 and 32а): the header with the initials, the name and the phone, which is
/// the name's button; the rows for the addresses, the language, support, the
/// two documents and the deletion; and the way out of the session under them
/// (`DL-75`, `DL-96` item 6). One list in every state of the profile: the
/// header shows a skeleton or the offline face where the data is missing, and
/// the rows stand under it (`DL-135`).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  /// Raised each time the name editor comes back with a saved name; the
  /// header plays its arrival on every new value.
  int _arrival = 0;

  Future<void> _editName() async {
    final bool? saved = await context.push<bool>(AppPaths.customerEditProfile);
    if (saved == true && mounted) {
      setState(() => _arrival++);
    }
  }

  void _logout() {
    final SessionState? state = ref.read(sessionControllerProvider).value;
    if (state is SignedIn) {
      ref.read(sessionControllerProvider.notifier).logout(state.activeMode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<CustomerProfile> profile = ref.watch(
      profileControllerProvider,
    );

    return CustomerTabScope(
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: const CustomerTabBar(current: CustomerTab.profile),
        body: Column(
          children: <Widget>[
            // The header runs up under the status bar.
            ColoredBox(
              key: const ValueKey<String>('profile-status-band'),
              color: KitColors.primaryDark,
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.paddingOf(context).top,
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey<String>('profile-list'),
                primary: true,
                padding: EdgeInsets.zero,
                children: <Widget>[
                  ProfileHeader(
                    profile: profile,
                    onEdit: _editName,
                    onRetry: () => ref.invalidate(profileControllerProvider),
                    arrival: _arrival,
                  ),
                  // The language and the way out are on the profile in every
                  // state of it.
                  ProfileRows(profile: profile, onLogout: _logout),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
