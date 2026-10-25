import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/session/session_controller.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/notifications/application/push_ports.dart';
import 'package:baraka_bozor/features/notifications/domain/push_event.dart';
import 'package:baraka_bozor/features/shopper/domain/shopper_orders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_customer_orders_repository.dart';
import '../../support/fake_shopper_orders_repository.dart';
import '../../support/fake_push.dart';
import '../../support/in_memory_stores.dart';

/// A tap on a push or a banner, through the real router and session, with
/// the push ports faked (`DL-115` (7)).
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakePushInbox inbox;
  late FakeBannerDisplay display;

  final PushTarget customerTarget = PushTarget(
    event: PushEvent.orderAccepted,
    orderId: orderOne,
  );
  final PushTarget shopperTarget = PushTarget(
    event: PushEvent.shoppingAssigned,
    orderId: shopperOrderA,
  );
  final PushTarget courierTarget = PushTarget(
    event: PushEvent.deliveryAssigned,
    orderId: shopperOrderA,
  );

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    inbox = FakePushInbox();
    display = FakeBannerDisplay();
  });

  void signInCustomer() {
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
  }

  void signInStaff(UserRole role) {
    tokens.tokens[SessionSlot.staff] = 's';
    auth.identities[SessionSlot.staff] = user(id: 's', role: role);
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        shopper: FakeShopperOrdersRepository(
          rows: <ShopperOrderRow>[],
          details: <String, ShopperOrder>{shopperOrderA: shopperOrder()},
        ),
        overrides: [
          pushInboxProvider.overrideWithValue(inbox),
          bannerDisplayProvider.overrideWithValue(display),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  GoRouter routerOf(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Scaffold).last));

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).last));

  String path(WidgetTester tester) => routerOf(tester).state.uri.path;

  Future<void> tap(WidgetTester tester, PushTarget target) async {
    inbox.openedPushes.add(target);
    await tester.pumpAndSettle();
  }

  testWidgets('a tap on a Customer push opens the order over the orders list', (
    WidgetTester tester,
  ) async {
    signInCustomer();
    await open(tester);

    await tap(tester, customerTarget);

    expect(path(tester), AppPaths.customerOrder(orderOne));
    routerOf(tester).pop();
    await tester.pumpAndSettle();
    expect(path(tester), AppPaths.customerOrders);
  });

  testWidgets(
    'a tap on a Shopper push in Customer mode switches to the staff mode',
    (WidgetTester tester) async {
      signInCustomer();
      signInStaff(UserRole.shopper);
      await open(tester);
      containerOf(tester)
          .read(sessionControllerProvider.notifier)
          .switchMode(SessionMode.customer);
      await tester.pumpAndSettle();

      await tap(tester, shopperTarget);

      final SignedIn session =
          containerOf(tester).read(sessionControllerProvider).value!
              as SignedIn;
      expect(session.activeMode, SessionMode.staff);
      expect(path(tester), AppPaths.shopperOrder(shopperOrderA));
    },
  );

  testWidgets(
    'a tap that launched the app opens the order once the session is known',
    (WidgetTester tester) async {
      signInCustomer();
      inbox.launch = customerTarget;

      await open(tester);

      expect(path(tester), AppPaths.customerOrder(orderOne));
    },
  );

  testWidgets(
    'a Customer tap that launched a two-session phone switches from the staff mode',
    (WidgetTester tester) async {
      signInCustomer();
      signInStaff(UserRole.shopper);
      inbox.launch = customerTarget;

      await open(tester);

      final SignedIn session =
          containerOf(tester).read(sessionControllerProvider).value!
              as SignedIn;
      expect(session.activeMode, SessionMode.customer);
      expect(path(tester), AppPaths.customerOrder(orderOne));
      routerOf(tester).pop();
      await tester.pumpAndSettle();
      expect(path(tester), AppPaths.customerOrders);
    },
  );

  testWidgets('a banner that launched the app opens the order', (
    WidgetTester tester,
  ) async {
    signInCustomer();
    display.launch = customerTarget;

    await open(tester);

    expect(path(tester), AppPaths.customerOrder(orderOne));
  });

  testWidgets('a tap on a banner opens the order', (WidgetTester tester) async {
    signInCustomer();
    await open(tester);

    display.tapped.add(customerTarget);
    await tester.pumpAndSettle();

    expect(path(tester), AppPaths.customerOrder(orderOne));
  });

  testWidgets("a Courier push on a Shopper's phone opens nothing", (
    WidgetTester tester,
  ) async {
    signInStaff(UserRole.shopper);
    await open(tester);
    final String before = path(tester);

    await tap(tester, courierTarget);

    expect(path(tester), before);
  });

  testWidgets('a Customer push without a Customer session opens nothing', (
    WidgetTester tester,
  ) async {
    signInStaff(UserRole.shopper);
    await open(tester);
    final String before = path(tester);

    await tap(tester, customerTarget);

    expect(path(tester), before);
  });

  testWidgets('a tap on the order already shown adds no page', (
    WidgetTester tester,
  ) async {
    signInCustomer();
    await open(tester);
    await tap(tester, customerTarget);

    await tap(tester, customerTarget);

    routerOf(tester).pop();
    await tester.pumpAndSettle();
    expect(path(tester), AppPaths.customerOrders);
  });

  testWidgets('a tap while signed out is dropped', (WidgetTester tester) async {
    await open(tester);

    await tap(tester, customerTarget);
    expect(path(tester), AppPaths.auth);

    signInCustomer();
    final SessionController session = containerOf(tester)
        .read(sessionControllerProvider.notifier);
    session.state = AsyncData<SessionState>(
      SignedIn(
        activeMode: SessionMode.customer,
        staffUser: null,
        customerUser: user(id: 'c'),
      ),
    );
    await tester.pumpAndSettle();

    expect(path(tester), isNot(AppPaths.customerOrder(orderOne)));
  });

  testWidgets(
    'a Customer tap while the staff password must change opens nothing',
    (WidgetTester tester) async {
      signInCustomer();
      tokens.tokens[SessionSlot.staff] = 's';
      auth.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.shopper,
        mustChangePassword: true,
      );
      await open(tester);
      expect(path(tester), AppPaths.changePassword);

      await tap(tester, customerTarget);

      final SignedIn session =
          containerOf(tester).read(sessionControllerProvider).value!
              as SignedIn;
      expect(session.activeMode, SessionMode.staff);
      expect(path(tester), AppPaths.changePassword);
    },
  );

  testWidgets('a tap while a staff step is pending opens nothing', (
    WidgetTester tester,
  ) async {
    signInCustomer();
    signInStaff(UserRole.shopper);
    await open(tester);
    containerOf(tester)
        .read(sessionControllerProvider.notifier)
        .state = AsyncData<SessionState>(
      SignedIn(
        activeMode: SessionMode.staff,
        staffUser: user(id: 's', role: UserRole.shopper),
        customerUser: user(id: 'c'),
        staffStep: StaffStep(
          token: 'a' * 64,
          expiresAt: DateTime.utc(2026, 10, 15, 10, 5),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(path(tester), AppPaths.staffPassword);

    await tap(tester, customerTarget);
    expect(path(tester), AppPaths.staffPassword);
    expect(
      (containerOf(tester).read(sessionControllerProvider).value! as SignedIn)
          .activeMode,
      SessionMode.staff,
    );
    await tap(tester, shopperTarget);
    expect(path(tester), AppPaths.staffPassword);
    expect(routerOf(tester).canPop(), isFalse);
  });

  testWidgets(
    'a Shopper tap while that Shopper must change the password opens nothing',
    (WidgetTester tester) async {
      tokens.tokens[SessionSlot.staff] = 's';
      auth.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.shopper,
        mustChangePassword: true,
      );
      await open(tester);
      expect(path(tester), AppPaths.changePassword);

      await tap(tester, shopperTarget);

      expect(path(tester), AppPaths.changePassword);
    },
  );

  testWidgets('a Customer tap while the Customer has no name opens nothing', (
    WidgetTester tester,
  ) async {
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c', fullName: null);
    await open(tester);
    final String before = path(tester);

    await tap(tester, customerTarget);

    expect(path(tester), before);
    expect(path(tester), isNot(AppPaths.customerOrder(orderOne)));
  });

  testWidgets(
    'a tap that waits through an unreachable server opens after the retry',
    (WidgetTester tester) async {
      tokens.tokens[SessionSlot.customer] = 'c';
      auth.identities[SessionSlot.customer] = const NetworkFailure();
      await open(tester);
      expect(
        containerOf(tester).read(sessionControllerProvider).value,
        isA<SessionUnreachable>(),
      );

      await tap(tester, customerTarget);
      expect(path(tester), isNot(AppPaths.customerOrder(orderOne)));

      auth.identities[SessionSlot.customer] = user(id: 'c');
      await containerOf(tester)
          .read(sessionControllerProvider.notifier)
          .retry();
      await tester.pumpAndSettle();

      expect(path(tester), AppPaths.customerOrder(orderOne));
    },
  );

  testWidgets('the latest of two early taps wins', (WidgetTester tester) async {
    signInCustomer();
    signInStaff(UserRole.shopper);
    auth.identities[SessionSlot.customer] = const NetworkFailure();
    auth.identities[SessionSlot.staff] = const NetworkFailure();
    await open(tester);

    await tap(tester, shopperTarget);
    await tap(tester, customerTarget);
    signInCustomer();
    signInStaff(UserRole.shopper);
    await containerOf(tester).read(sessionControllerProvider.notifier).retry();
    await tester.pumpAndSettle();

    final SignedIn session =
        containerOf(tester).read(sessionControllerProvider).value! as SignedIn;
    expect(session.activeMode, SessionMode.customer);
    expect(path(tester), AppPaths.customerOrder(orderOne));
  });
}
