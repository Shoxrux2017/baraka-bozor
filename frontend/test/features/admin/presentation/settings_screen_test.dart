import 'dart:async';

import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/platform/map_links.dart';
import 'package:baraka_bozor/core/formatting/tashkent_time.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_note.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_card.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_segmented.dart';
import 'package:baraka_bozor/features/admin/application/admin_providers.dart';
import 'package:baraka_bozor/features/admin/domain/business_settings.dart';
import 'package:baraka_bozor/features/admin/presentation/admin_paths.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_courier_orders_repository.dart';
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

  Switch providerSwitch(WidgetTester tester, Finder row) => tester
      .widget<Switch>(find.descendant(of: row, matching: find.byType(Switch)));

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    repository = FakeSettingsRepository();
    tokens.tokens[SessionSlot.staff] = 's';
    auth.identities[SessionSlot.staff] = user(role: UserRole.admin);
  });

  Future<void> openPanel(
    WidgetTester tester, {
    Size size = const Size(1440, 2600),
    Locale device = const Locale('uz'),
    List<Override> extra = const <Override>[],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        surface: Surface.web,
        device: device,
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repository),
          ...extra,
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await openPanel(tester);
    await tester.tap(
      find.byKey(
        const ValueKey<String>('panel-section-${AdminPaths.settings}'),
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

      expect(find.text(l10n(tester).roleAdmin), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('panel-rail')), findsOneWidget);
      expect(repository.loads, 0, reason: 'the landing page loads nothing');

      await tester.tap(
        find.byKey(
          const ValueKey<String>('panel-section-${AdminPaths.settings}'),
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
      expect(textOf(tester, field('support_phone')), '+998712000000');
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

  testWidgets('the settings fields type at 13 in ink', (
    WidgetTester tester,
  ) async {
    await openSettings(tester);

    final EditableText typed = tester.widget<EditableText>(
      find.descendant(
        of: field('markup_percent'),
        matching: find.byType(EditableText),
      ),
    );
    expect(typed.style.fontSize, 13);
    expect(typed.style.color, KitColors.ink);
  });

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

  testWidgets('a malformed support phone is refused and nothing is sent', (
    WidgetTester tester,
  ) async {
    await openSettings(tester);

    await tester.enterText(field('support_phone'), '998712000000');
    await submit(tester);

    expect(find.text(l10n(tester).fieldSupportPhone), findsOneWidget);
    expect(repository.saved, isEmpty);
  });

  testWidgets('a cleared support phone is sent as null', (
    WidgetTester tester,
  ) async {
    await openSettings(tester);

    await tester.enterText(field('support_phone'), '');
    await submit(tester);

    expect(repository.saved.single.supportPhone, isNull);
    expect(textOf(tester, field('support_phone')), '');
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

  testWidgets(
    'a save answered with the same timestamp still shows the stored values',
    (WidgetTester tester) async {
      // Two saves within one second, or a save the server did not need to
      // store, answer with the updated_at the form already had.
      repository.onSave = (BusinessSettingsDraft draft) =>
          settings(markupPercent: '12.50');
      await openSettings(tester);

      await tester.enterText(field('markup_percent'), '12.5');
      await submit(tester);

      expect(textOf(tester, field('markup_percent')), '12.50');
    },
  );

  testWidgets('a form nobody changed is not sent', (WidgetTester tester) async {
    await openSettings(tester);

    await submit(tester);

    expect(repository.saved, isEmpty);
    expect(find.text(l10n(tester).settingsNoChanges), findsOneWidget);
  });

  testWidgets('the last change is shown in Tashkent time', (
    WidgetTester tester,
  ) async {
    // 05:00 UTC is 10:00 in Tashkent, whatever the device's zone.
    await openSettings(tester);

    expect(
      find.text(l10n(tester).settingsUpdatedAt('26.09.2026 10:00')),
      findsOneWidget,
    );
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
    final Completer<void> gate = Completer<void>();
    repository.saveGate = gate;
    await openSettings(tester);

    await tester.enterText(field('markup_percent'), '14');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    // While the save is on its way the fields wait with it.
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: field('closes_at'),
              matching: find.byType(TextField),
            ),
          )
          .enabled,
      isFalse,
    );
    gate.complete();
    repository.saveGate = null;
    await tester.pumpAndSettle();

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

    expect(providerSwitch(tester, click).value, isFalse);
    expect(providerSwitch(tester, click).onChanged, isNull);
    await tester.tap(click);
    await tester.pump();

    gate.complete();
    await tester.pumpAndSettle();

    expect(repository.switched, <(PaymentProvider, bool)>[
      (PaymentProvider.click, true),
    ]);
    expect(providerSwitch(tester, click).value, isTrue);
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

    expect(providerSwitch(tester, payme).value, isFalse);
    expect(providerSwitch(tester, payme).onChanged, isNotNull);
    expect(find.text(l10n(tester).errorNetwork), findsOneWidget);

    // Another provider's success leaves the reason Payme was refused.
    final Finder click = find.byKey(const ValueKey<String>('provider-click'));
    await tester.tap(click);
    await tester.pumpAndSettle();
    expect(providerSwitch(tester, click).value, isTrue);
    expect(find.text(l10n(tester).errorNetwork), findsOneWidget);
  });

  testWidgets('on a narrow window the sections are in a drawer', (
    WidgetTester tester,
  ) async {
    await openPanel(tester, size: const Size(600, 1200));

    expect(find.byKey(const ValueKey<String>('panel-rail')), findsNothing);
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

  testWidgets(
    'an Operator sent to the settings lands in their own area, loading nothing',
    (WidgetTester tester) async {
      auth.identities[SessionSlot.staff] = user(role: UserRole.operator);
      await openPanel(tester);

      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go(AdminPaths.settings);
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).roleOperator), findsOneWidget);
      expect(find.text(l10n(tester).settingsTitle), findsNothing);
      expect(repository.loads, 0);
    },
  );

  Future<void> openSettingsAt(
    WidgetTester tester,
    Size size, {
    Locale device = const Locale('uz'),
    List<Override> extra = const <Override>[],
  }) async {
    await openPanel(tester, size: size, device: device, extra: extra);
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go(AdminPaths.settings);
    await tester.pumpAndSettle();
  }

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  /// The panel card whose title is [title].
  Finder card(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(PanelCard));

  Finder inCard(String title, Finder inner) =>
      find.descendant(of: card(title), matching: inner);

  testWidgets('the form stands in four cards and the payment card beside', (
    WidgetTester tester,
  ) async {
    await openSettingsAt(tester, const Size(1048, 1000));
    final AppLocalizations t = l10n(tester);

    for (final String key in <String>[
      'markup_percent',
      'price_tolerance_percent',
      'service_fee_mode',
      'service_fee_fixed_uzs',
      'delivery_fee_uzs',
      'minimum_order_uzs',
    ]) {
      expect(
        inCard(t.settingsPricingSection, field(key)),
        findsOneWidget,
        reason: key,
      );
    }
    expect(inCard(t.settingsHoursSection, field('opens_at')), findsOneWidget);
    expect(inCard(t.settingsHoursSection, field('closes_at')), findsOneWidget);
    expect(
      inCard(t.settingsHoursSection, find.text(t.settingsHoursHint)),
      findsOneWidget,
    );
    for (final String key in <String>[
      'service_centre_latitude',
      'service_centre_longitude',
      'service_radius_km',
    ]) {
      expect(inCard(t.settingsAreaSection, field(key)), findsOneWidget);
    }
    expect(
      inCard(t.settingsAreaSection, find.text(t.settingsAreaHint)),
      findsOneWidget,
    );
    expect(
      inCard(t.settingsDeliverySection, field('support_phone')),
      findsOneWidget,
    );
    expect(
      inCard(
        t.settingsDeliverySection,
        field('delivery_delay_threshold_minutes'),
      ),
      findsOneWidget,
    );

    final Rect pricing = tester.getRect(card(t.settingsPricingSection));
    final Rect providers = tester.getRect(byKey('providers-card'));
    expect(providers.left, greaterThanOrEqualTo(pricing.right));
    expect(providers.top, lessThan(pricing.bottom));
    expect(providers.width, 372);
  });

  testWidgets('below the two-column width the payment card is last', (
    WidgetTester tester,
  ) async {
    await openSettingsAt(tester, const Size(1047, 1000));

    final Rect bar = tester.getRect(save);
    final Rect providers = tester.getRect(byKey('providers-card'));
    expect(providers.top, greaterThanOrEqualTo(bar.bottom));
  });

  testWidgets('the form keeps what was typed across the two-column width', (
    WidgetTester tester,
  ) async {
    await openSettingsAt(tester, const Size(1048, 1000));
    await tester.enterText(field('markup_percent'), '17');
    await tester.pump();

    tester.view.physicalSize = const Size(1047, 1000);
    await tester.pumpAndSettle();

    expect(textOf(tester, field('markup_percent')), '17');
  });

  testWidgets('the fee mode is a segmented switch', (
    WidgetTester tester,
  ) async {
    await openSettingsAt(tester, const Size(1440, 2600));

    expect(
      tester
          .widget<PanelSegmented<ServiceFeeMode>>(field('service_fee_mode'))
          .selected,
      ServiceFeeMode.fixed,
    );
    await tester.tap(byKey('fee-mode-percentage'));
    await tester.pumpAndSettle();

    expect(field('service_fee_percent'), findsOneWidget);
    expect(field('service_fee_fixed_uzs'), findsNothing);
    await tester.enterText(field('service_fee_percent'), '2.5');
    await submit(tester);

    final BusinessSettingsDraft sent = repository.saved.single;
    expect(sent.serviceFeeMode, ServiceFeeMode.percentage);
    expect(sent.serviceFeePercent, '2.5');
    expect(sent.serviceFeeFixedUzs, isNull);
  });

  testWidgets('the header says when the settings last changed', (
    WidgetTester tester,
  ) async {
    await openSettingsAt(tester, const Size(1440, 1000));
    final AppLocalizations t = l10n(tester);

    final Finder updated = byKey('settings-updated-at');
    expect(
      tester.widget<Text>(updated).data,
      t.settingsUpdatedAt(TashkentTime.format(DateTime.utc(2026, 9, 26, 5))),
    );
    expect(
      tester.getTopLeft(updated).dy,
      greaterThan(tester.getBottomLeft(find.text(t.settingsTitle)).dy - 1),
    );
  });

  testWidgets('the save bar says what a change touches', (
    WidgetTester tester,
  ) async {
    await openSettingsAt(tester, const Size(1440, 1000));
    final AppLocalizations t = l10n(tester);

    final Finder noteText = find.text(t.settingsSaveNote);
    expect(noteText, findsOneWidget);
    expect(tester.getCenter(noteText).dx, lessThan(tester.getCenter(save).dx));
    expect(
      (tester.getCenter(noteText).dy - tester.getCenter(save).dy).abs(),
      lessThan(40),
    );
  });

  testWidgets('the saved centre opens on a map', (WidgetTester tester) async {
    final FakeMapLinks maps = FakeMapLinks();
    await openSettingsAt(
      tester,
      const Size(1440, 1000),
      extra: <Override>[mapPointLinksProvider.overrideWithValue(maps)],
    );
    final AppLocalizations t = l10n(tester);

    expect(find.text(t.settingsShowOnMap), findsOneWidget);
    // The saved centre opens, not the text being typed.
    await tester.enterText(field('service_centre_latitude'), '40.1');
    await tester.tap(byKey('settings-map-link'));
    await tester.pumpAndSettle();

    expect(maps.opened, <String>['41.311081,69.240562']);
    expect(find.text(t.settingsMapFailed), findsNothing);
  });

  testWidgets('a centre that does not open says so', (
    WidgetTester tester,
  ) async {
    final FakeMapLinks maps = FakeMapLinks()..opens = false;
    await openSettingsAt(
      tester,
      const Size(1440, 1000),
      extra: <Override>[mapPointLinksProvider.overrideWithValue(maps)],
    );

    await tester.tap(byKey('settings-map-link'));
    await tester.pumpAndSettle();

    expect(find.text(l10n(tester).settingsMapFailed), findsOneWidget);
  });

  testWidgets('with no saved centre there is no map link', (
    WidgetTester tester,
  ) async {
    repository.current = settings(
      serviceCentreLatitude: null,
      serviceCentreLongitude: null,
      serviceRadiusKm: null,
    );
    await openSettingsAt(tester, const Size(1440, 1000));

    expect(byKey('settings-map-link'), findsNothing);
  });

  testWidgets('the payment card says online payment is not open yet', (
    WidgetTester tester,
  ) async {
    repository.providerSettings = providers(
      enabled: <PaymentProvider>{PaymentProvider.click},
    );
    await openSettingsAt(tester, const Size(1440, 1000));
    final AppLocalizations t = l10n(tester);

    final Finder amber = find.ancestor(
      of: find.text(t.providersCashOnlyNote),
      matching: find.byWidgetPredicate(
        (Widget w) => w is KitNote && w.tone == KitTone.amber,
      ),
    );
    expect(amber, findsOneWidget);
    expect(find.text(t.providersInstant), findsOneWidget);
    for (final PaymentProvider provider in PaymentProvider.values) {
      final Finder row = byKey('provider-${provider.code}');
      expect(
        find.descendant(
          of: row,
          matching: find.text(
            provider == PaymentProvider.click ? t.providerOn : t.providerOff,
          ),
        ),
        findsOneWidget,
        reason: provider.code,
      );
      expect(
        find.descendant(of: row, matching: find.text(provider.brand)),
        findsOneWidget,
      );
    }
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    for (final Size size in const <Size>[Size(1440, 900), Size(820, 1180)]) {
      testWidgets('the settings hold at the extremes '
          '(${device.languageCode} ${size.width.toInt()})', (
        WidgetTester tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        repository.switchFailure = const NetworkFailure();

        await openSettingsAt(tester, size, device: device);
        expect(tester.takeException(), isNull);

        await tester.enterText(field('markup_percent'), '12,5');
        await tester.enterText(field('opens_at'), 'x');
        await tester.enterText(field('closes_at'), '');
        await tester.enterText(field('service_centre_longitude'), '');
        await tester.enterText(field('service_radius_km'), '0');
        await tester.enterText(field('delivery_delay_threshold_minutes'), '0');
        await tester.enterText(field('support_phone'), '99');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final Finder payme = byKey('provider-payme');
        await tester.ensureVisible(payme);
        await tester.tap(payme);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(repository.saved, isEmpty);
      });
    }
  }
}
