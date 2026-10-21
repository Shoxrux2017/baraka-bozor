import 'package:baraka_bozor/core/formatting/phone_format.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/platform/phone_calls.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_call_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_shopper_orders_repository.dart';

/// The card that dials a phone.
void main() {
  const String phone = '+998901234567';
  late FakePhoneCalls calls;

  setUp(() => calls = FakePhoneCalls());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [phoneCallsProvider.overrideWithValue(calls)],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: KitCallCard(title: 'Recipient', phone: phone),
          ),
        ),
      ),
    );
  }

  testWidgets('a call card dials its phone', (WidgetTester tester) async {
    await pump(tester);

    await tester.tap(find.byType(KitCallCard));
    await tester.pump();

    expect(calls.calls, <String>[phone]);
    expect(find.text('Recipient'), findsOneWidget);
    expect(find.text(formatPhone(phone)), findsOneWidget);
  });

  testWidgets('a dialer that cannot open says the number', (
    WidgetTester tester,
  ) async {
    calls.opens = false;
    await pump(tester);

    await tester.tap(find.byType(KitCallCard));
    await tester.pump();

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(KitCallCard)),
    );
    expect(find.text(l10n.callFailed(formatPhone(phone))), findsOneWidget);
  });
}
