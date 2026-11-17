import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/features/auth/presentation/auth_notice.dart';
import 'package:baraka_bozor/features/auth/presentation/rise_in.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// With the system asking for less motion the sign-in fades still take their
/// 200 ms: the platform's own 5 % speed-up is not applied to them (`DL-139`).
void main() {
  void reduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  double opacityOf(WidgetTester tester, Finder inside) => tester
      .widget<Opacity>(
        find.descendant(of: inside, matching: find.byType(Opacity)).first,
      )
      .opacity;

  testWidgets('RiseIn fades over 200 ms with reduced motion', (
    WidgetTester tester,
  ) async {
    reduceMotion(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: RiseIn(key: ValueKey<String>('rise'), child: Text('a')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      opacityOf(tester, find.byKey(const ValueKey<String>('rise'))),
      inExclusiveRange(0.3, 0.7),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('AuthNotice fades over 200 ms with reduced motion', (
    WidgetTester tester,
  ) async {
    reduceMotion(tester);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: AuthNotice(
          view: const AuthNoticeView(
            tone: AuthNoticeTone.danger,
            icon: Icons.wifi_off,
            text: 'No internet',
          ),
          onAction: (AuthNoticeAction _) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      opacityOf(tester, find.byKey(const ValueKey<String>('auth-notice'))),
      inExclusiveRange(0.3, 0.7),
    );
    await tester.pumpAndSettle();
  });
}
