import 'package:baraka_bozor/main.dart' show noAutomaticRetry;
import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/widgets/brand_wordmark.dart';
import 'package:baraka_bozor/features/auth/presentation/auth_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_stores.dart';
import '../../../support/nonlinear_text_scaler.dart';

void main() {
  final GlobalKey buttonKey = GlobalKey();
  const double keyboard = 300;

  Future<void> open(
    WidgetTester tester, {
    required TextScaler scaler,
    bool disableAnimations = false,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: [
          preferenceStoreProvider.overrideWithValue(InMemoryPreferenceStore()),
          deviceLocaleProvider.overrideWithValue(const Locale('ru')),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: scaler,
              disableAnimations: disableAnimations,
            ),
            child: child!,
          ),
          home: AuthScaffold(
            title: 'Вход',
            subtitle: List<String>.filled(14, 'Длинное пояснение').join(' '),
            keepVisible: buttonKey,
            child: Padding(
              key: buttonKey,
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton(
                onPressed: () {},
                child: const Text('Получить код'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void raiseKeyboard(WidgetTester tester) {
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
  }

  testWidgets('large text with the keyboard up keeps the button in view', (
    WidgetTester tester,
  ) async {
    await open(tester, scaler: const NonlinearTextScaler(2));

    raiseKeyboard(tester);
    await tester.pump();
    await tester.pumpAndSettle();

    final Rect button = tester.getRect(find.byType(FilledButton));
    expect(button.bottom, lessThanOrEqualTo(640 - keyboard));
    expect(button.top, greaterThanOrEqualTo(0));
  });

  testWidgets('with reduced motion the button is in view at once', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      scaler: const NonlinearTextScaler(2),
      disableAnimations: true,
    );

    raiseKeyboard(tester);
    await tester.pump();
    await tester.pump();

    expect(
      tester.getRect(find.byType(FilledButton)).bottom,
      lessThanOrEqualTo(640 - keyboard),
    );
  });

  testWidgets('the wordmark hides only with large text and the keyboard', (
    WidgetTester tester,
  ) async {
    await open(tester, scaler: const NonlinearTextScaler(2));
    expect(find.byType(BrandWordmark), findsOneWidget);

    raiseKeyboard(tester);
    await tester.pumpAndSettle();
    expect(find.byType(BrandWordmark), findsNothing);

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.byType(BrandWordmark), findsOneWidget);
  });

  testWidgets('at normal text the wordmark stays with the keyboard up', (
    WidgetTester tester,
  ) async {
    await open(tester, scaler: TextScaler.noScaling);

    raiseKeyboard(tester);
    await tester.pumpAndSettle();

    expect(find.byType(BrandWordmark), findsOneWidget);
  });

  testWidgets('the back arrow carries the given label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: [
          preferenceStoreProvider.overrideWithValue(InMemoryPreferenceStore()),
          deviceLocaleProvider.overrideWithValue(const Locale('ru')),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AuthScaffold(
            title: 'Код',
            onBack: () {},
            backLabel: 'Назад, к номеру телефона',
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Назад, к номеру телефона'), findsOneWidget);
  });
}
