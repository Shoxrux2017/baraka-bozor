import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/widgets/kit/quiet_icon.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/auth/presentation/auth_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_connectivity_signal.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/nonlinear_text_scaler.dart';

void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository repository;
  late FakeConnectivitySignal connectivity;

  final Finder retryButton = find.byKey(const ValueKey<String>('retry-button'));
  final Finder title = find.byKey(const ValueKey<String>('unreachable-title'));
  final Finder checked = find.byKey(
    const ValueKey<String>('unreachable-checked'),
  );

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.staff] = 's';
    repository = FakeAuthRepository()
      ..identities[SessionSlot.staff] = const NetworkFailure();
    connectivity = FakeConnectivitySignal();
  });

  Future<void> open(
    WidgetTester tester, {
    DateTime Function()? clock,
    TextScaler? textScaler,
    Surface surface = Surface.mobile,
  }) async {
    await tester.pumpWidget(
      appUnderTest(
        surface: surface,
        tokens: tokens,
        repository: repository,
        connectivity: connectivity,
        device: const Locale('ru'),
        clock: clock,
        textScaler: textScaler,
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Takes the screen down, so no timer of its own is left pending.
  Future<void> leave(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  int asked() => repository.meCalls(SessionSlot.staff);

  Finder quietIcon(IconData icon) => find.byWidgetPredicate(
    (Widget w) => w is QuietIcon && w.icon == icon,
    description: 'a QuietIcon of $icon',
  );

  double sizeOf(WidgetTester tester, Finder text) =>
      tester.widget<Text>(text).style!.fontSize!;

  List<String> announced(WidgetTester tester) => tester
      .takeAnnouncements()
      .map((CapturedAccessibilityAnnouncement a) => a.message)
      .toList();

  List<String> semanticsLabels(WidgetTester tester) {
    final List<String> labels = <String>[];
    void walk(SemanticsNode node) {
      labels.add(node.label);
      node.visitChildren((SemanticsNode child) {
        walk(child);
        return true;
      });
    }

    walk(tester.getSemantics(find.byType(Scaffold).first));
    return labels;
  }

  /// Records `HapticFeedback` calls of the platform channel.
  List<String> hapticsOf(WidgetTester tester) {
    final List<String> calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return calls;
  }

  testWidgets('no answer says Нет связи with a grey icon', (
    WidgetTester tester,
  ) async {
    await open(tester);

    expect(quietIcon(Icons.wifi_off), findsOneWidget);
    expect(find.byType(StatusHalo), findsNothing);
    expect(find.text('Нет связи'), findsOneWidget);
    expect(sizeOf(tester, title), 20);
    final Finder body = find.text(
      'Проверьте мобильный интернет или Wi‑Fi. Приложение откроется само, '
      'когда связь появится.',
    );
    expect(body, findsOneWidget);
    expect(sizeOf(tester, body), 15);
    expect(checked, findsNothing);
    await leave(tester);
  });

  testWidgets('an error answer says BarakaBozor is down', (
    WidgetTester tester,
  ) async {
    repository.identities[SessionSlot.staff] = refusal(500, 'server_error');

    await open(tester);

    expect(quietIcon(Icons.cloud_off), findsOneWidget);
    expect(find.text('BarakaBozor сейчас недоступен'), findsOneWidget);
    expect(
      find.text(
        'Интернет на телефоне в порядке. Попробуйте через пару минут — '
        'приложение тоже проверит само.',
      ),
      findsOneWidget,
    );
    await leave(tester);
  });

  testWidgets('a pressed retry shows Проверяем… then the checked time', (
    WidgetTester tester,
  ) async {
    final List<String> haptics = hapticsOf(tester);
    await open(tester, clock: () => DateTime.utc(2026, 11, 16, 4, 41));

    await tester.tap(retryButton);
    await tester.pump();

    expect(find.text('Проверяем…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(checked, findsNothing);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();

    expect(find.text('Повторить'), findsOneWidget);
    expect(find.text('Связи пока нет · проверено в 09:41'), findsOneWidget);
    expect(haptics, <String>[
      'HapticFeedbackType.mediumImpact',
    ], reason: 'one medium impact when a pressed check finds nothing');

    final double during = tester
        .widget<Opacity>(
          find.ancestor(of: checked, matching: find.byType(Opacity)).first,
        )
        .opacity;
    await tester.pump(const Duration(milliseconds: 200));
    final double after = tester
        .widget<Opacity>(
          find.ancestor(of: checked, matching: find.byType(Opacity)).first,
        )
        .opacity;
    expect(during, lessThan(1));
    expect(after, 1);
    await leave(tester);
  });

  testWidgets('a check is spoken and its result too', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester, clock: () => DateTime.utc(2026, 11, 16, 4, 41));
    announced(tester);

    await tester.tap(retryButton);
    await tester.pump();

    expect(announced(tester), <String>['Проверяем связь…']);
    expect(
      find.bySemanticsLabel('Проверяем связь…'),
      findsOneWidget,
      reason: 'the busy button reads as the check',
    );
    expect(
      semanticsLabels(tester).where((String l) => l.contains('недоступна')),
      isEmpty,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Проверяем связь…')),
      isSemantics(label: 'Проверяем связь…', hasEnabledState: false),
      reason: 'not drawn as a disabled button either',
    );

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(announced(tester), <String>['Связи пока нет']);
    expect(
      find.bySemanticsLabel('Связи пока нет, проверено в 09:41'),
      findsOneWidget,
    );

    repository.identities[SessionSlot.staff] = user(role: UserRole.courier);
    await tester.tap(retryButton);
    await tester.pump();
    announced(tester);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();

    expect(announced(tester), <String>['Связь есть, открываем приложение']);
    handle.dispose();
    await leave(tester);
  });

  testWidgets('a refused token ends the wait and is announced too', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester);
    announced(tester);
    repository.identities[SessionSlot.staff] = refusal(
      401,
      'authentication_required',
    );

    await tester.tap(retryButton);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();

    expect(announced(tester), contains('Связь есть, открываем приложение'));
    expect(retryButton, findsNothing);
    handle.dispose();
    await leave(tester);
  });

  testWidgets('the screen checks by itself at 5, 10, 20 and 30 s', (
    WidgetTester tester,
  ) async {
    await open(tester);
    final int first = asked();

    Future<void> after(int ms, int expectedMore) async {
      await tester.pump(Duration(milliseconds: ms));
      expect(asked() - first, expectedMore, reason: 'at ${ms}ms more');
    }

    await after(4999, 0);
    await after(1, 1);
    await after(9999, 1);
    await after(1, 2);
    await after(19999, 2);
    await after(1, 3);
    await after(29999, 3);
    await after(1, 4);
    await after(29999, 4);
    await after(1, 5);
    await leave(tester);
  });

  testWidgets('returning to the app or the network checks at once', (
    WidgetTester tester,
  ) async {
    await open(tester);
    final int first = asked();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(asked(), first, reason: 'leaving the app asks nothing');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(asked(), first + 1);

    connectivity.regain();
    await tester.pump();
    expect(asked(), first + 2);
    await leave(tester);
  });

  testWidgets('the panel says «Нет связи» in panel words', (
    WidgetTester tester,
  ) async {
    await open(tester, surface: Surface.web);
    expect(
      find.text(
        'Проверьте подключение к интернету. Панель откроется сама, когда '
        'связь появится.',
      ),
      findsOneWidget,
    );
    await leave(tester);

    repository.identities[SessionSlot.staff] = refusal(500, 'server_error');
    await open(tester, surface: Surface.web);
    expect(
      find.text(
        'Интернет в порядке. Попробуйте через пару минут — панель тоже '
        'проверит сама.',
      ),
      findsOneWidget,
    );
    await leave(tester);
  });

  testWidgets('the series sleeps in the background and wakes on return', (
    WidgetTester tester,
  ) async {
    await open(tester);
    final int first = asked();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    expect(asked(), first, reason: 'nothing is asked in the background');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(asked(), first + 1);
    await leave(tester);
  });

  testWidgets('a flapping network starts one check at a time', (
    WidgetTester tester,
  ) async {
    await open(tester);
    final int first = asked();
    repository.holdMe[SessionSlot.staff] = Completer<void>();

    connectivity.regain();
    await tester.pump();
    connectivity.regain();
    connectivity.regain();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(asked() - first, 1);

    repository.holdMe[SessionSlot.staff]!.complete();
    await tester.pump();
    await leave(tester);
  });

  testWidgets('leaving the screen stops the checks', (
    WidgetTester tester,
  ) async {
    await open(tester);
    repository.identities[SessionSlot.staff] = user(role: UserRole.courier);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey<String>('retry-button')), findsNothing);

    repository.calls.clear();
    connectivity.regain();
    await tester.pump(const Duration(seconds: 60));

    expect(repository.calls.where((String c) => c.startsWith('me:')), isEmpty);
    await leave(tester);
  });

  group('at large text', () {
    testWidgets('the screen scrolls without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final SemanticsHandle handle = tester.ensureSemantics();
      repository.identities[SessionSlot.staff] = refusal(500, 'server_error');
      await open(
        tester,
        clock: () => DateTime.utc(2026, 11, 16, 4, 41),
        textScaler: NonlinearTextScaler(2),
      );

      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

      await tester.ensureVisible(retryButton);
      await tester.pump();
      await tester.tap(retryButton);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text('BarakaBozor пока недоступен · проверено в 09:41'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
      await leave(tester);
    });

    testWidgets('and at 100 % the guideline holds', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await open(tester);

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
      await leave(tester);
    });
  });
}
