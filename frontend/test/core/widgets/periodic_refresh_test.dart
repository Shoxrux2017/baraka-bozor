import 'package:baraka_bozor/core/widgets/periodic_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The refresh of a screen while it is shown (`DL-54` (15)), on its own:
/// every interval while active, never while its load failed or runs, and
/// only while its route is on top and the app in the foreground.
void main() {
  late int refreshes;

  setUp(() => refreshes = 0);

  Widget screen({required bool active}) => PeriodicRefresh(
    active: active,
    onRefresh: () => refreshes++,
    child: const Text('shown'),
  );

  Future<void> host(WidgetTester tester, {required bool active}) =>
      tester.pumpWidget(MaterialApp(home: screen(active: active)));

  testWidgets('it refreshes every ten seconds while active, and not while '
      'inactive', (WidgetTester tester) async {
    await host(tester, active: true);

    await tester.pump(const Duration(seconds: 9));
    expect(refreshes, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(refreshes, 1);
    await tester.pump(const Duration(seconds: 10));
    expect(refreshes, 2);

    // A failed or running load: nothing, however long.
    await host(tester, active: false);
    await tester.pump(const Duration(minutes: 5));
    expect(refreshes, 2);

    // Loaded again: the next refresh is a whole interval later.
    await host(tester, active: true);
    await tester.pump(const Duration(seconds: 9));
    expect(refreshes, 2);
    await tester.pump(const Duration(seconds: 1));
    expect(refreshes, 3);
  });

  testWidgets('it waits while its route is covered, and refreshes once shown', (
    WidgetTester tester,
  ) async {
    await host(tester, active: true);
    final NavigatorState navigator = tester.state(find.byType(Navigator));

    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const Text('over it')),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(refreshes, 0);

    navigator.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(refreshes, 1);
  });

  testWidgets('it waits while the app is in the background', (
    WidgetTester tester,
  ) async {
    await host(tester, active: true);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(refreshes, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 10));
    expect(refreshes, 1);
  });

  testWidgets('leaving the screen leaves no refresh behind', (
    WidgetTester tester,
  ) async {
    await host(tester, active: true);
    await tester.pumpWidget(const SizedBox.shrink());

    await tester.pump(const Duration(seconds: 30));
    expect(refreshes, 0);
  });
}
