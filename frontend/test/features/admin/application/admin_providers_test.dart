import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/session/session_controller.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/features/admin/application/admin_providers.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_repository.dart';

/// A session controller whose state the test sets.
class _Session extends SessionController {
  _Session(this._initial);

  final SessionState _initial;

  @override
  Future<SessionState> build() async => _initial;

  void show(SessionState next) => state = AsyncData<SessionState>(next);
}

/// `staffAccountProvider` names the signed-in staff account and changes only
/// when that account does, so the Admin controllers start over exactly then.
void main() {
  ProviderContainer containerWith(SessionState initial) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(() => _Session(initial)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('no staff account, no id', () async {
    final ProviderContainer signedOut = containerWith(const SignedOut());
    await signedOut.read(sessionControllerProvider.future);
    expect(signedOut.read(staffAccountProvider), isNull);

    final ProviderContainer customerOnly = containerWith(
      SignedIn(
        activeMode: SessionMode.customer,
        staffUser: null,
        customerUser: user(id: 'c'),
      ),
    );
    await customerOnly.read(sessionControllerProvider.future);
    expect(customerOnly.read(staffAccountProvider), isNull);
  });

  test('the staff account is named, and a change of its details is no change of account', () async {
    // A derived provider recomputes when read; each change is read at once,
    // as a watching widget would.
    final AppUser admin = user(id: 'a-1', role: UserRole.admin);
    final ProviderContainer container = containerWith(
      SignedIn(
        activeMode: SessionMode.staff,
        staffUser: admin,
        customerUser: null,
      ),
    );
    await container.read(sessionControllerProvider.future);
    final List<String?> seen = <String?>[];
    container.listen<String?>(
      staffAccountProvider,
      (String? previous, String? next) => seen.add(next),
      fireImmediately: true,
    );

    final _Session session =
        container.read(sessionControllerProvider.notifier) as _Session;
    session.show(
      SignedIn(
        activeMode: SessionMode.staff,
        staffUser: admin.copyWith(preferredLanguage: AppLanguage.ru),
        customerUser: null,
      ),
    );
    container.read(staffAccountProvider);
    session.show(
      SignedIn(
        activeMode: SessionMode.staff,
        staffUser: user(id: 'a-2', role: UserRole.admin),
        customerUser: null,
      ),
    );
    container.read(staffAccountProvider);
    session.show(const SignedOut());
    container.read(staffAccountProvider);

    expect(seen, <String?>['a-1', 'a-2', null]);
  });
}
