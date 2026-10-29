import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/features/checkout/presentation/checkout_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Finder byKey(String key) => find.byKey(ValueKey<String>(key));

MaterialApp app(Widget home, {Locale locale = const Locale('ru')}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

Widget host(Widget child) => app(
  Scaffold(
    body: SingleChildScrollView(child: Form(child: child)),
  ),
);

/// The footer at the bottom of a screen, as it stands in the checkout.
Widget footerHost(Widget footer, {Locale locale = const Locale('ru')}) => app(
  Scaffold(body: const SizedBox.expand(), bottomNavigationBar: footer),
  locale: locale,
);

void main() {
  final AppLocalizations ru = lookupAppLocalizations(const Locale('ru'));
  String estimate(int amount) =>
      ru.cartLineEstimate(MoneyFormat.uzs(amount, AppLanguage.ru));

  testWidgets('busy, the green button says what it does', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        CheckoutFooter(
          totalUzs: 47600,
          estimate: true,
          busy: false,
          busyLabel: 'Оформляем',
          onOrder: () {},
        ),
      ),
    );
    expect(find.text(estimate(47600)), findsOneWidget);
    expect(find.text('Заказать'), findsOneWidget);
    await tester.pumpWidget(
      host(
        CheckoutFooter(
          totalUzs: 47600,
          estimate: true,
          busy: true,
          busyLabel: 'Оформляем',
          onOrder: () {},
        ),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: byKey('checkout-confirm'),
        matching: find.text('Оформляем'),
      ),
      findsOneWidget,
    );
    final Finder spinner = find.byType(CircularProgressIndicator);
    expect(spinner, findsOneWidget);
    expect(
      find.ancestor(of: spinner, matching: find.byType(ExcludeSemantics)),
      findsWidgets,
    );
    expect(
      tester.widget<FilledButton>(byKey('checkout-confirm')).onPressed,
      isNull,
    );
    final Material material = tester.widget<Material>(
      find.descendant(
        of: byKey('checkout-confirm'),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, KitColors.primary);
    await tester.pumpWidget(
      host(
        const CheckoutFooter(
          totalUzs: null,
          estimate: true,
          busy: false,
          busyLabel: '',
          onOrder: null,
        ),
      ),
    );
    expect(
      tester.widget<FilledButton>(byKey('checkout-confirm')).onPressed,
      isNull,
    );
  });

  testWidgets('a recount shows было → стало above the button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      footerHost(
        CheckoutFooter(
          totalUzs: 48600,
          recountedFromUzs: 47600,
          estimate: true,
          busy: false,
          busyLabel: '…',
          onOrder: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(byKey('checkout-refreshed')).dy,
      lessThan(tester.getTopLeft(byKey('checkout-confirm')).dy),
    );
    final Finder rich = find.descendant(
      of: byKey('checkout-refreshed'),
      matching: find.byType(RichText),
    );
    final String plain = tester
        .widgetList<RichText>(rich)
        .map((RichText t) => t.text.toPlainText())
        .join();
    expect(plain, contains(estimate(47600)));
    expect(plain, contains(estimate(48600)));
    bool struck = false;
    for (final RichText text in tester.widgetList<RichText>(rich)) {
      text.text.visitChildren((InlineSpan span) {
        if (span is TextSpan &&
            span.toPlainText() == estimate(47600) &&
            span.style?.decoration == TextDecoration.lineThrough) {
          struck = true;
        }
        return true;
      });
    }
    expect(struck, isTrue);
  });

  testWidgets('an equal recount says the order was recounted', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      footerHost(
        CheckoutFooter(
          totalUzs: 47600,
          recountedFromUzs: 47600,
          estimate: true,
          busy: false,
          busyLabel: '…',
          onOrder: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(ru.checkoutRecounted), findsOneWidget);
    expect(byKey('checkout-refreshed'), findsOneWidget);
    expect(find.textContaining('→'), findsNothing);
  });

  testWidgets('the notice rises in 0.28 s; at once with reduced motion', (
    WidgetTester tester,
  ) async {
    Widget footer() => CheckoutFooter(
      totalUzs: 48600,
      recountedFromUzs: 47600,
      estimate: true,
      busy: false,
      busyLabel: '…',
      onOrder: () {},
    );
    double opacity() => tester
        .widget<Opacity>(
          find.descendant(
            of: byKey('checkout-refreshed'),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    await tester.pumpWidget(footerHost(footer()));
    await tester.pump();
    expect(opacity(), lessThan(0.2));
    await tester.pump(const Duration(milliseconds: 140));
    expect(opacity(), allOf(greaterThan(0.2), lessThan(1)));
    await tester.pump(const Duration(milliseconds: 160));
    expect(opacity(), 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: footerHost(footer()),
      ),
    );
    await tester.pump();
    expect(opacity(), 1);
  });

  testWidgets('without an address a line says why', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      footerHost(
        CheckoutFooter(
          totalUzs: null,
          estimate: true,
          busy: false,
          busyLabel: '…',
          onOrder: null,
          why: ru.checkoutWhyNoAddress,
        ),
      ),
    );
    final Text why = tester.widget<Text>(byKey('checkout-why'));
    expect(why.data, ru.checkoutWhyNoAddress);
    expect(why.style?.fontSize, 12);
    expect(why.style?.color, KitColors.muted);
    expect(
      tester.widget<FilledButton>(byKey('checkout-confirm')).onPressed,
      isNull,
    );
  });

  testWidgets('with large text the total stands over Заказать', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      footerHost(
        CheckoutFooter(
          totalUzs: 99999999,
          estimate: true,
          busy: false,
          busyLabel: '…',
          onOrder: () {},
        ),
        locale: const Locale('uz'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getBottomLeft(byKey('checkout-footer-total')).dy,
      lessThanOrEqualTo(tester.getTopLeft(byKey('checkout-confirm')).dy),
    );
    expect(
      find.descendant(
        of: byKey('checkout-confirm'),
        matching: find.byType(FittedBox),
      ),
      findsNothing,
    );
  });

  testWidgets('beside it when they fit', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      footerHost(
        CheckoutFooter(
          totalUzs: 47600,
          estimate: true,
          busy: false,
          busyLabel: '…',
          onOrder: () {},
        ),
      ),
    );
    expect(byKey('checkout-footer-total'), findsNothing);
    expect(
      find.descendant(
        of: byKey('checkout-confirm'),
        matching: find.text(estimate(47600)),
      ),
      findsOneWidget,
    );
  });
}
