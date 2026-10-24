import 'dart:math' as math;

import 'package:flutter/foundation.dart' show protected;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/paged.dart';

/// One page of a list a screen shows, which a sure answer on one row's own
/// page can take that row off at once, before the list's own reload answers
/// (`DL-113`). The reload of a list under a covered page waits until that
/// page closes, and meanwhile the list would show its last answer.
abstract class ListPageController<T> extends AsyncNotifier<Paged<T>> {
  /// The id the row is known by, as the routes and the API write it.
  @protected
  String idOf(T row);

  /// Takes the rows with [id] off the page it holds, whatever the case of
  /// the id. The page keeps its place and the total goes down by the rows
  /// removed; before the first answer, after a failed one, or when no row
  /// matches, nothing changes.
  void drop(String id) {
    final Paged<T>? page = state.value;
    if (page == null || state.hasError) {
      return;
    }
    final String wanted = id.toLowerCase();
    final List<T> kept = page.items
        .where((T row) => idOf(row).toLowerCase() != wanted)
        .toList(growable: false);
    final int removed = page.items.length - kept.length;
    if (removed == 0) {
      return;
    }
    state = AsyncData<Paged<T>>(
      Paged<T>(
        items: kept,
        page: page.page,
        perPage: page.perPage,
        total: math.max(0, page.total - removed),
        lastPage: page.lastPage,
      ),
    );
  }
}

/// Drops the row [id] from [list] when a screen holds it; a list nobody
/// holds is not loaded for a drop (`DL-113`).
void dropRow<T>(
  Ref ref,
  AsyncNotifierProvider<ListPageController<T>, Paged<T>> list,
  String id,
) {
  if (ref.exists(list)) {
    ref.read(list.notifier).drop(id);
  }
}
