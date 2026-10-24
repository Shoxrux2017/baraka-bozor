import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/notifications/application/push_ports.dart';
import 'package:baraka_bozor/features/notifications/domain/push_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_customer_orders_repository.dart';
import '../../support/fake_push.dart';
import '../../support/in_memory_stores.dart';

/// The foreground banner and the channel's name, through the real router and
/// the session, with the push ports faked (`DL-115`).
void main() {
  const String otherOrder = '0192f0a0-0000-7000-8000-00000000c002';

  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakePushInbox inbox;
  late FakeBannerDisplay display;

  IncomingPush pushFor(PushEvent event, String orderId, {String? tag}) =>
      IncomingPush(
        title: 'Title',
        body: 'Body',
        tag: tag ?? 'delivery-$orderId',
        target: PushTarget(event: event, orderId: orderId),
      );

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.customer] = 'c';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.customer] = user(id: 'c');
    inbox = FakePushInbox();
    display = FakeBannerDisplay();
  });

  Future<void> open(
    WidgetTester tester, {
    Locale device = const Locale('uz'),
  }) async {
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        device: device,
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

  Future<void> arrive(WidgetTester tester, IncomingPush push) async {
    inbox.foregroundPushes.add(push);
    await tester.pumpAndSettle();
  }

  testWidgets('a push in the foreground shows its banner', (
    WidgetTester tester,
  ) async {
    await open(tester);

    final IncomingPush push = pushFor(PushEvent.orderAccepted, orderOne);
    await arrive(tester, push);

    expect(display.shown, hasLength(1));
    expect(display.shown.single.title, 'Title');
    expect(display.shown.single.tag, push.tag);
    expect(display.shown.single.target?.orderId, orderOne);
  });

  testWidgets('a push for the order on screen shows no banner', (
    WidgetTester tester,
  ) async {
    await open(tester);
    routerOf(tester).push(AppPaths.customerOrder(orderOne));
    await tester.pumpAndSettle();

    await arrive(tester, pushFor(PushEvent.approvalRequired, orderOne));

    expect(display.shown, isEmpty);
  });

  testWidgets('a push for another order still shows', (
    WidgetTester tester,
  ) async {
    await open(tester);
    routerOf(tester).push(AppPaths.customerOrder(orderOne));
    await tester.pumpAndSettle();

    await arrive(tester, pushFor(PushEvent.orderAccepted, otherOrder));

    expect(display.shown, hasLength(1));
    expect(display.shown.single.target?.orderId, otherOrder);
  });

  testWidgets('a Shopper push while the phone is in Customer mode shows', (
    WidgetTester tester,
  ) async {
    tokens.tokens[SessionSlot.staff] = 's';
    auth.identities[SessionSlot.staff] = user(id: 's', role: UserRole.shopper);
    await open(tester);
    routerOf(tester).push(AppPaths.customerOrder(orderOne));
    await tester.pumpAndSettle();

    await arrive(tester, pushFor(PushEvent.shoppingAssigned, orderOne));

    expect(display.shown, hasLength(1));
  });

  testWidgets('a push that names no order still shows', (
    WidgetTester tester,
  ) async {
    await open(tester);

    await arrive(
      tester,
      const IncomingPush(title: 'Title', body: 'Body', tag: 'm-1'),
    );

    expect(display.shown, hasLength(1));
    expect(display.shown.single.target, isNull);
  });

  testWidgets(
    'the channel is named in the app language and renamed when it changes',
    (WidgetTester tester) async {
      await open(tester);

      expect(display.prepared, isNotEmpty);
      expect(display.prepared.last.name, 'Buyurtmalar');
      expect(
        display.prepared.last.description,
        "Yangi buyurtmalar, savollar va holat o'zgarishlari",
      );

      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).last),
      );
      await container
          .read(languageControllerProvider.notifier)
          .select(AppLanguage.ru);
      await tester.pumpAndSettle();

      expect(display.prepared.last.name, 'Заказы');
      expect(
        display.prepared.last.description,
        'Новые заказы, вопросы и изменения статуса',
      );
    },
  );
}
