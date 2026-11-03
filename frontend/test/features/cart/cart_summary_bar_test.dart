import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/cart/domain/cart.dart';
import 'package:baraka_bozor/features/cart/presentation/cart_summary_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_cart_repository.dart';
import '../../support/nonlinear_text_scaler.dart';

/// A Customer account a test can change, as a sign-out or another sign-in does.
class _Account extends Notifier<String?> {
  @override
  String? build() => 'c';

  void set(String? id) => state = id;
}

final NotifierProvider<_Account, String?> _account =
    NotifierProvider<_Account, String?>(_Account.new);

void main() {
  late FakeCartRepository cart;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  /// The sum as the bar draws it: the amount whole, an ordinary space before
  /// the currency so that only the currency may drop to a second line.
  String sum(int uzs) =>
      '≈ ${MoneyFormat.grouped(uzs)} ${MoneyFormat.currency(AppLanguage.ru)}';

  Cart one(int total, {String id = tomatoLine}) =>
      cartOf(<Map<String, Object?>>[cartLineJson(id: id, total: total)]);

  setUp(() {
    cart = FakeCartRepository();
  });

  /// Opens a screen with the bar at the foot of a stack. With [gated] the bar
  /// is built only once the cart is loaded, as when a screen opens over a cart
  /// that is already known.
  Future<void> pump(
    WidgetTester tester, {
    TextScaler? scaler,
    bool reduced = false,
    bool gated = false,
    Size size = const Size(375, 640),
    FakeViewPadding padding = FakeViewPadding.zero,
    bool switchable = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = padding;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (int count, Object error) => null,
        overrides: [
          if (switchable)
            customerAccountProvider.overrideWith(
              (Ref ref) => ref.watch(_account),
            )
          else
            customerAccountProvider.overrideWithValue('c'),
          cartRepositoryProvider.overrideWithValue(cart),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (BuildContext context, Widget? home) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: scaler ?? MediaQuery.textScalerOf(context),
              disableAnimations: reduced,
            ),
            child: home!,
          ),
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                const SizedBox.expand(),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: gated
                      ? Consumer(
                          builder: (BuildContext context, WidgetRef ref, _) =>
                              ref.watch(currentCartProvider).hasValue
                              ? const CartSummaryBar()
                              : const SizedBox.shrink(),
                        )
                      : const CartSummaryBar(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  void showCart(WidgetTester tester, Cart next) {
    ProviderScope.containerOf(tester.element(find.byType(Scaffold)))
        .read(cartProvider('c').notifier)
        .show(next);
  }

  group('the entrance and the exit', () {
    testWidgets(
      'slides up when the first line comes and down when the cart empties',
      (WidgetTester tester) async {
        await pump(tester);
        expect(byKey('cart-summary'), findsNothing);

        showCart(tester, one(18000));
        await tester.pump();
        expect(byKey('cart-summary'), findsOneWidget);
        final double top0 = tester.getTopLeft(byKey('cart-summary')).dy;
        final double height = tester.getSize(byKey('cart-summary')).height;
        expect(
          top0,
          greaterThanOrEqualTo(640),
          reason: 'it starts wholly below the screen',
        );

        await tester.pump(const Duration(milliseconds: 180));
        final double mid = tester.getTopLeft(byKey('cart-summary')).dy;
        expect(mid, lessThan(top0 - height * 0.3));

        await tester.pump(const Duration(milliseconds: 180));
        final double rest = tester.getTopLeft(byKey('cart-summary')).dy;
        expect(rest, lessThan(mid));
        expect(rest + height, lessThan(640 - 11));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.getTopLeft(byKey('cart-summary')).dy, rest);

        showCart(tester, cartOf(<Map<String, Object?>>[]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        expect(byKey('cart-summary'), findsOneWidget);
        expect(tester.getTopLeft(byKey('cart-summary')).dy, greaterThan(rest));

        await tester.pump(const Duration(milliseconds: 121));
        expect(byKey('cart-summary'), findsNothing);
      },
    );

    testWidgets('stands at once when the screen opens with a cart', (
      WidgetTester tester,
    ) async {
      cart = FakeCartRepository(cart: one(18000));
      await pump(tester, gated: true);

      expect(byKey('cart-summary'), findsOneWidget);
      final Rect bar = tester.getRect(byKey('cart-summary'));
      expect(bar.bottom, lessThan(640 - 11));
      expect(find.text(sum(18000)), findsOneWidget);
    });

    testWidgets('with reduced motion it fades', (WidgetTester tester) async {
      await pump(tester, reduced: true);
      showCart(tester, one(18000));
      await tester.pump();
      final Rect first = tester.getRect(byKey('cart-summary'));

      double opacity() => tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: byKey('cart-summary'),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;

      expect(opacity(), 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(), greaterThan(0));
      expect(opacity(), lessThan(1));
      expect(tester.getRect(byKey('cart-summary')), first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(), 1);
    });
  });

  testWidgets('another account leaves no trace of the last cart', (
    WidgetTester tester,
  ) async {
    cart = FakeCartRepository(cart: one(18000));
    await pump(tester, switchable: true);
    await tester.pump(const Duration(seconds: 1));
    expect(byKey('cart-summary'), findsOneWidget);

    ProviderScope.containerOf(tester.element(find.byType(Scaffold)))
        .read(_account.notifier)
        .set(null);
    await tester.pump();

    expect(byKey('cart-summary'), findsNothing);
    expect(find.text(sum(18000)), findsNothing);
  });

  group('the sum and the picture', () {
    testWidgets('the sum rolls to the new value', (WidgetTester tester) async {
      cart = FakeCartRepository(cart: one(18000));
      await pump(tester, gated: true);
      expect(find.text(sum(18000)), findsOneWidget);

      showCart(tester, one(36000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text(sum(18000)), findsOneWidget);
      expect(find.text(sum(36000)), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 121));
      expect(find.text(sum(18000)), findsNothing);
      expect(find.text(sum(36000)), findsOneWidget);
    });

    testWidgets('the count changes in place', (WidgetTester tester) async {
      cart = FakeCartRepository(cart: one(18000));
      await pump(tester, gated: true);
      expect(find.text('1 товар'), findsOneWidget);

      showCart(
        tester,
        cartOf(<Map<String, Object?>>[
          cartLineJson(id: tomatoLine, total: 18000),
          cartLineJson(id: breadLine, productId: breadProduct, total: 4000),
        ]),
      );
      await tester.pump();
      expect(find.text('1 товар'), findsNothing);
      expect(find.text('2 товара'), findsOneWidget);
    });
  });

  group('large text', () {
    testWidgets('at text x2 an arrow replaces the words and the sum is whole', (
      WidgetTester tester,
    ) async {
      cart = FakeCartRepository(cart: one(123456));
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pump(
        tester,
        gated: true,
        scaler: const NonlinearTextScaler(2),
        // Wider than a phone: the Ahem test font is a full em per glyph.
        size: const Size(420, 640),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('В корзину'), findsNothing);
      final Icon arrow = tester.widget<Icon>(find.byIcon(Icons.chevron_right));
      expect(arrow.size, 30);
      expect(arrow.color, Colors.white);

      // The currency is parted by an ordinary space, so it may wrap alone.
      final Finder total = find.text(
        '≈ ${MoneyFormat.grouped(123456)} ${MoneyFormat.currency(AppLanguage.ru)}',
      );
      expect(total, findsOneWidget);
      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        total,
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.widget<Text>(total).overflow, isNot(TextOverflow.ellipsis));

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold)),
      );
      expect(
        find.bySemanticsLabel(
          l10n.cartSummarySpoken(
            l10n.cartSummaryCount(1),
            MoneyFormat.uzs(123456, AppLanguage.ru),
          ),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('a sum too wide beside the words gives way to the arrow', (
      WidgetTester tester,
    ) async {
      cart = FakeCartRepository(cart: one(142100));
      await pump(tester, gated: true, size: const Size(400, 640));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('В корзину'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      final Finder total = find.text(sum(142100));
      expect(total, findsOneWidget);
      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        total,
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.size.height, lessThan(15 * 1.7), reason: 'one line');
    });

    testWidgets('a sum that fits keeps the words', (WidgetTester tester) async {
      cart = FakeCartRepository(cart: one(142100));
      await pump(tester, gated: true, size: const Size(600, 640));

      expect(find.textContaining('В корзину'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.text(sum(142100)), findsOneWidget);
    });

    testWidgets('reserved fits the bar at text x2', (
      WidgetTester tester,
    ) async {
      cart = FakeCartRepository(cart: one(1234567));
      late double reserved;
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerAccountProvider.overrideWithValue('c'),
            cartRepositoryProvider.overrideWithValue(cart),
          ],
          child: MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (BuildContext context, Widget? home) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const NonlinearTextScaler(2)),
              child: home!,
            ),
            home: Scaffold(
              body: Stack(
                children: <Widget>[
                  Builder(
                    builder: (BuildContext context) {
                      reserved = CartSummaryBar.reserved(context);
                      return const SizedBox.expand();
                    },
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Consumer(
                      builder: (BuildContext context, WidgetRef ref, _) =>
                          ref.watch(currentCartProvider).hasValue
                          ? const CartSummaryBar()
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      final Rect bar = tester.getRect(
        find
            .descendant(
              of: find.byType(CartSummaryBar),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(reserved, greaterThanOrEqualTo(bar.height - 0.5));
    });
  });

  testWidgets('lying with a notch it keeps clear of the camera', (
    WidgetTester tester,
  ) async {
    cart = FakeCartRepository(cart: one(18000));
    await pump(
      tester,
      gated: true,
      size: const Size(812, 375),
      padding: const FakeViewPadding(left: 47, right: 47),
    );

    final Rect bar = tester.getRect(byKey('cart-summary'));
    expect(bar.left, greaterThanOrEqualTo(67));
    expect(bar.right, lessThanOrEqualTo(812 - 67));
  });
}
