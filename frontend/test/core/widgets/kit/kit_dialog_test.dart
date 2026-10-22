import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The kit dialog every panel window is built on: a title row with a ×, a
/// muted subtitle, a body, and a hold while an action runs.
void main() {
  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  Future<void> pumpHost(
    WidgetTester tester, {
    required WidgetBuilder builder,
    String? subtitle,
    Size size = const Size(1000, 800),
    double maxWidth = kitDialogWidth,
    bool barrierDismissible = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey<String>('open'),
                onPressed: () => showKitDialog<void>(
                  context: context,
                  dialogKey: 'test-dialog',
                  title: 'Dialog title',
                  subtitle: subtitle,
                  builder: builder,
                  maxWidth: maxWidth,
                  barrierDismissible: barrierDismissible,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(byKey('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a kit dialog shows its title and subtitle and closes on its ×', (
    WidgetTester tester,
  ) async {
    await pumpHost(
      tester,
      subtitle: 'Order line',
      builder: (BuildContext context) => const Text('body'),
    );
    expect(byKey('test-dialog'), findsOneWidget);
    expect(find.text('Dialog title'), findsOneWidget);
    expect(find.text('Order line'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
    expect(tester.getSize(byKey('test-dialog')).width, 480);

    await tester.tap(byKey('test-dialog-close'));
    await tester.pumpAndSettle();

    expect(byKey('test-dialog'), findsNothing);
  });

  testWidgets('a narrow window leaves 16 either side', (
    WidgetTester tester,
  ) async {
    await pumpHost(
      tester,
      size: const Size(360, 800),
      builder: (BuildContext context) => const Text('body'),
    );

    expect(tester.getSize(byKey('test-dialog')).width, 328);
  });

  testWidgets('a held dialog stays through its ×, the scrim and back', (
    WidgetTester tester,
  ) async {
    await pumpHost(
      tester,
      builder: (BuildContext context) =>
          const PopScope(canPop: false, child: Text('body')),
    );

    await tester.tap(byKey('test-dialog-close'));
    await tester.pumpAndSettle();
    expect(byKey('test-dialog'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(byKey('test-dialog'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(byKey('test-dialog'), findsOneWidget);
  });

  testWidgets('a kit dialog takes a wider max width', (
    WidgetTester tester,
  ) async {
    await pumpHost(
      tester,
      size: const Size(1440, 900),
      maxWidth: 720,
      builder: (BuildContext context) => const Text('body'),
    );
    expect(tester.getSize(byKey('test-dialog')).width, 720);

    await tester.tap(byKey('test-dialog-close'));
    await tester.pumpAndSettle();

    await pumpHost(
      tester,
      size: const Size(600, 900),
      maxWidth: 720,
      builder: (BuildContext context) => const Text('body'),
    );
    expect(tester.getSize(byKey('test-dialog')).width, 568);
  });

  testWidgets('a dialog that may not be dismissed holds against the scrim', (
    WidgetTester tester,
  ) async {
    await pumpHost(
      tester,
      barrierDismissible: false,
      builder: (BuildContext context) => const Text('body'),
    );

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(byKey('test-dialog'), findsOneWidget);

    await tester.tap(byKey('test-dialog-close'));
    await tester.pumpAndSettle();
    expect(byKey('test-dialog'), findsNothing);
  });

  testWidgets(
    'the dialog buttons put a red confirm beside an outlined cancel',
    (WidgetTester tester) async {
      int submitted = 0;
      Future<void> pumpButtons({required bool busy}) => tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => kitDialogButtons(
                context: context,
                busy: busy,
                confirmKey: const ValueKey<String>('action-confirm'),
                confirm: 'Remove',
                submit: () => submitted++,
                destructive: true,
              ),
            ),
          ),
        ),
      );

      await pumpButtons(busy: false);
      final FilledButton confirm = tester.widget<FilledButton>(
        byKey('action-confirm'),
      );
      expect(
        confirm.style!.backgroundColor!.resolve(<WidgetState>{}),
        KitColors.danger,
      );
      expect(byKey('action-cancel'), findsOneWidget);
      await tester.tap(byKey('action-confirm'));
      expect(submitted, 1);

      await pumpButtons(busy: true);
      expect(
        tester.widget<FilledButton>(byKey('action-confirm')).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(byKey('action-cancel')).onPressed,
        isNull,
      );
    },
  );
}
