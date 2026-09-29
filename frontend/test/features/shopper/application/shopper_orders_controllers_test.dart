import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/session/session_controller.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/shopper/application/shopper_orders_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_shopper_orders_repository.dart';

/// A session controller whose state the test sets.
class _Session extends SessionController {
  _Session(this._initial);

  final SessionState _initial;

  @override
  Future<SessionState> build() async => _initial;

  void show(SessionState next) => state = AsyncData<SessionState>(next);
}

SignedIn _shopper(String id) => SignedIn(
  activeMode: SessionMode.staff,
  staffUser: user(id: id, role: UserRole.shopper),
  customerUser: null,
);

/// The Shopper's list is kept per account (`DL-28` (9)).
void main() {
  test('another account starts the list on its first page', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(() => _Session(_shopper('s-1'))),
        shopperOrdersRepositoryProvider.overrideWithValue(
          FakeShopperOrdersRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.future);
    container.listen<int>(shopperOrdersPageProvider, (_, _) {});

    container.read(shopperOrdersPageProvider.notifier).goToPage(2);
    expect(container.read(shopperOrdersPageProvider), 2);

    (container.read(sessionControllerProvider.notifier) as _Session).show(
      _shopper('s-2'),
    );
    expect(container.read(shopperOrdersPageProvider), 1);
  });
}
