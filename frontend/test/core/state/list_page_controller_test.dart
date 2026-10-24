import 'dart:async';

import 'package:baraka_bozor/core/network/paged.dart';
import 'package:baraka_bozor/core/state/list_page_controller.dart';
import 'package:flutter/foundation.dart' show protected;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

int _builds = 0;
Completer<Paged<String>> _answer = Completer<Paged<String>>();

class _PageNumber extends Notifier<int> {
  @override
  int build() => 1;

  void change() => state++;
}

final NotifierProvider<_PageNumber, int> _pageNumber =
    NotifierProvider<_PageNumber, int>(_PageNumber.new);

class _Rows extends ListPageController<String> {
  @override
  Future<Paged<String>> build() {
    ref.watch(_pageNumber);
    _builds++;
    return _builds == 1 ? _answer.future : Completer<Paged<String>>().future;
  }

  @override
  @protected
  String idOf(String row) => row;
}

final AsyncNotifierProvider<_Rows, Paged<String>> _rows =
    AsyncNotifierProvider.autoDispose<_Rows, Paged<String>>(_Rows.new);

/// The drop as a provider hands it out, called after the provider is built.
final Provider<void Function()> _dropA = Provider<void Function()>(
  (Ref ref) =>
      () => dropRow<String>(ref, _rows, 'a'),
);

Paged<String> _page(List<String> items) =>
    Paged<String>(items: items, page: 2, perPage: 3, total: 7, lastPage: 3);

void main() {
  late ProviderContainer container;

  setUp(() {
    _builds = 0;
    _answer = Completer<Paged<String>>();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<void> hold() async {
    container.listen(_rows, (_, _) {});
    _answer.complete(_page(<String>['a', 'b', 'c']));
    await container.read(_rows.future);
  }

  test('drop takes the row off and keeps the page where it is', () async {
    await hold();
    container.read(_rows.notifier).drop('b');
    final AsyncValue<Paged<String>> state = container.read(_rows);
    expect(state, isA<AsyncData<Paged<String>>>());
    final Paged<String> page = state.value!;
    expect(page.items, <String>['a', 'c']);
    expect(page.page, 2);
    expect(page.perPage, 3);
    expect(page.total, 6);
    expect(page.lastPage, 3);
  });

  test('drop matches the id in any case', () async {
    await hold();
    container.read(_rows.notifier).drop('B');
    expect(container.read(_rows).value!.items, <String>['a', 'c']);
  });

  test('a row not on the page changes nothing', () async {
    await hold();
    final AsyncValue<Paged<String>> before = container.read(_rows);
    container.read(_rows.notifier).drop('z');
    expect(container.read(_rows), same(before));
  });

  test(
    'before the first answer, and after a failed one, drop changes nothing',
    () async {
      container.listen(_rows, (_, _) {});
      container.read(_rows.notifier).drop('a');
      expect(container.read(_rows), isA<AsyncLoading<Paged<String>>>());
      expect(container.read(_rows).hasValue, isFalse);

      _answer.completeError(StateError('lost'));
      await expectLater(container.read(_rows.future), throwsStateError);
      container.read(_rows.notifier).drop('a');
      expect(container.read(_rows).hasError, isTrue);
      expect(container.read(_rows).hasValue, isFalse);
    },
  );

  test('dropRow leaves a list nobody holds unloaded', () {
    container.read(_dropA)();
    expect(_builds, 0);
    expect(container.exists(_rows), isFalse);
  });

  test('dropRow takes the row off a list a screen holds', () async {
    await hold();
    container.read(_dropA)();
    expect(container.read(_rows).value!.items, <String>['b', 'c']);
  });

  test("a page change's load is left as it is", () async {
    await hold();
    container.read(_pageNumber.notifier).change();
    final AsyncValue<Paged<String>> loading = container.read(_rows);
    expect(loading.isLoading, isTrue);
    expect(loading.isReloading, isTrue);

    container.read(_rows.notifier).drop('a');
    final AsyncValue<Paged<String>> after = container.read(_rows);
    expect(after.isLoading, isTrue);
    expect(after.isReloading, isTrue);
    expect(after, isNot(isA<AsyncData<Paged<String>>>()));
  });
}
