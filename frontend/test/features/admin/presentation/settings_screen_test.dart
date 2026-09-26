import 'dart:async';

import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/admin/application/admin_providers.dart';
import 'package:baraka_bozor/features/admin/domain/business_settings.dart';
import 'package:baraka_bozor/features/admin/presentation/admin_paths.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_settings_repository.dart';
import '../../../support/in_memory_stores.dart';

/// The Admin's settings screen (W1-9) through the real router, session and
/// screens, against a settings repository in memory.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeSettingsRepository repository;

  Finder field(String apiKey) => find.byKey(ValueKey<String>('field-$apiKey'));
  final Finder save = find.byKey(const ValueKey<String>('settings-save'));

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  String textOf(WidgetTester tester, Finder finder) => tester
      .widget<EditableText>(
        find.descendant(of: finder, matching: find.byType(EditableText)),
      )
      .controller
      .text;

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    repository = FakeSettingsRepository();
    tokens.tokens[SessionSlot.staff] = 's';
    auth.identities[SessionSlot.staff] = user(role: UserRole.admin);
  });

  Future<void> openPanel(
    WidgetTester tester, {
    Size size = const Size(1400, 2600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        surface: Surface.web,
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await openPanel(tester);
    await tester.tap(
      find.byKey(
        const ValueKey<String>('admin-section-${AdminPaths.settings}'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'an Admin lands on the panel and opens the settings with the stored values',
    (WidgetTester tester) async {
      await openPanel(tester);

      expect(find.text(l10n(tester).shellAdmin), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('admin-rail')), findsOneWidget);
      expect(repository.loads, 0, reason: 'the landing page loads nothing');

      await tester.tap(
        find.byKey(
          const ValueKey<String>('admin-section-${AdminPaths.settings}'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).settingsTitle), findsOneWidget);
      expect(textOf(tester, field('markup_percent')), '15.00');
      expect(
        textOf(tester, field('service_fee_fixed_uzs')),
        MoneyFormat.grouped(5000),
      );
      expect(
        textOf(tester, field('delivery_fee_uzs')),
        MoneyFormat.grouped(15000),
      );
      expect(
        textOf(tester, field('minimum_order_uzs')),
        MoneyFormat.grouped(100000),
      );
      expect(textOf(tester, field('opens_at')), '09:00');
      expect(textOf(tester, field('service_centre_latitude')), '41.311081');
      expect(textOf(tester, field('delivery_delay_threshold_minutes')), '30');
      expect(field('service_fee_percent'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('settings-updated-at')),
        findsOneWidget,
      );
      for (final PaymentProvider provider in PaymentProvider.values) {
        expect(
          find.byKey(ValueKey<String>('provider-${provider.code}')),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets(
    'switching the fee mode swaps the value field, and the save sends only that value',
    (WidgetTester tester) async {
      await openSettings(tester);

      await tester.tap(find.text(l10n(tester).settingsServiceFeePercentage));
      await tester.pumpAndSettle();
      expect(field('service_fee_fixed_uzs'), findsNothing);
      await tester.enterText(field('service_fee_percent'), '2.5');
      await tester.enterText(field('delivery_fee_uzs'), '20 000');
      await submit(tester);

      final BusinessSettingsDraft sent = repository.saved.single;
      expect(sent.serviceFeeMode, ServiceFeeMode.percentage);
      expect(sent.serviceFeePercent, '2.5');
      expect(sent.serviceFeeFixedUzs, isNull);
      expect(sent.deliveryFeeUzs, 20000);
      expect(sent.markupPercent, '15.00');
      expect(sent.opensAt, '09:00');
      expect(sent.deliveryDelayThresholdMinutes, 30);
      expect(find.text(l10n(tester).settingsSaved), findsOneWidget);
    },
  );

  testWidgets('the form refuses what the API would refuse and sends nothing', (
    WidgetTester tester,
  ) async {
    await openSettings(tester);

    await tester.enterText(field('markup_percent'), '12,5');
    await tester.enterText(field('closes_at'), '');
    await tester.enterText(field('service_centre_longitude'), '');
    await tester.enterText(field('delivery_delay_threshold_minutes'), '0');
    await submit(tester);

    expect(find.text(l10n(tester).fieldPercent), findsOneWidget);
    expect(find.text(l10n(tester).fieldPairIncomplete), findsNWidgets(2));
    expect(find.text(l10n(tester).fieldMinutes), findsOneWidget);
    expect(repository.saved, isEmpty);
  });

  testWidgets('a saved change is shown as the server stored it', (
    WidgetTester tester,
  ) async {
    repository.onSave = (BusinessSettingsDraft draft) => settings(
      markupPercent: '12.50',
      updatedAt: DateTime.utc(2026, 9, 26, 7),
    );
    await openSettings(tester);

    await tester.enterText(field('markup_percent'), '12.5');
    await submit(tester);

    expect(repository.saved.single.markupPercent, '12.5');
    expect(textOf(tester, field('markup_percent')), '12.50');
  });

  testWidgets('a field the server refused is marked until it is edited', (
    WidgetTester tester,
  ) async {
    repository.saveFailure = const ApiRefusal(
      ApiError(
        status: 422,
        code: 'validation_failed',
        errors: <String, List<String>>{
          'closes_at': <String>['Must differ from opens_at.'],
        },
      ),
    );
    await openSettings(tester);

    await submit(tester);

    expect(find.text(l10n(tester).fieldRejected), findsOneWidget);
    expect(find.text(l10n(tester).errorValidationFailed), findsOneWidget);

    await tester.enterText(field('closes_at'), '22:00');
    await tester.pumpAndSettle();
    expect(find.text(l10n(tester).fieldRejected), findsNothing);

    await submit(tester);
    expect(repository.saved, hasLength(2));
    expect(repository.saved.last.closesAt, '22:00');
    expect(find.text(l10n(tester).settingsSaved), findsOneWidget);
  });

  testWidgets('a load failure explains itself and offers a retry', (
    WidgetTester tester,
  ) async {
    repository.loadFailure = const NetworkFailure();
    await openSettings(tester);

    expect(find.text(l10n(tester).errorNetwork), findsOneWidget);
    expect(field('markup_percent'), findsNothing);

    repository.loadFailure = null;
    await tester.tap(find.text(l10n(tester).retryButton));
    await tester.pumpAndSettle();

    expect(textOf(tester, field('markup_percent')), '15.00');
  });

  testWidgets('a provider switch shows the server answer, not the tap', (
    WidgetTester tester,
  ) async {
    final Completer<void> gate = Completer<void>();
    repository.switchGate = gate;
    await openSettings(tester);

    final Finder click = find.byKey(const ValueKey<String>('provider-click'));
    await tester.ensureVisible(click);
    await tester.tap(click);
    await tester.pump();

    expect(tester.widget<SwitchListTile>(click).value, isFalse);
    expect(tester.widget<SwitchListTile>(click).onChanged, isNull);
    await tester.tap(click);
    await tester.pump();

    gate.complete();
    await tester.pumpAndSettle();

    expect(repository.switched, <(PaymentProvider, bool)>[
      (PaymentProvider.click, true),
    ]);
    expect(tester.widget<SwitchListTile>(click).value, isTrue);
  });

  testWidgets('a refused provider switch stays where the server has it', (
    WidgetTester tester,
  ) async {
    repository.switchFailure = const NetworkFailure();
    await openSettings(tester);

    final Finder payme = find.byKey(const ValueKey<String>('provider-payme'));
    await tester.ensureVisible(payme);
    await tester.tap(payme);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(payme).value, isFalse);
    expect(tester.widget<SwitchListTile>(payme).onChanged, isNotNull);
    expect(find.text(l10n(tester).errorNetwork), findsOneWidget);
  });

  testWidgets('on a narrow window the sections are in a drawer', (
    WidgetTester tester,
  ) async {
    await openPanel(tester, size: const Size(600, 1200));

    expect(find.byKey(const ValueKey<String>('admin-rail')), findsNothing);
    await tester.tap(
      find.byTooltip(
        MaterialLocalizations.of(tester.element(find.byType(Scaffold).first))
            .openAppDrawerTooltip,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n(tester).adminSectionSettings).last);
    await tester.pumpAndSettle();

    expect(find.text(l10n(tester).settingsTitle), findsOneWidget);
  });
}
