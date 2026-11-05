import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/server_text.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/session/customer_account.dart';

/// The server's limit of a rating's comment, in characters (`DL-134`).
const int rateCommentMax = 500;

/// From this length the comment counter shows (`DL-134`).
const int rateCounterFrom = 450;

/// Whether [stars] asks for the reasons and the Operator's call: 1 to 3.
bool isLowRating(int? stars) => stars != null && stars >= 1 && stars <= 3;

/// A rating as it is sent (`DL-134`).
final class RateBody {
  const RateBody({
    required this.stars,
    required this.reasons,
    required this.comment,
  });

  final int stars;
  final List<RatingReason> reasons;
  final String? comment;

  @override
  bool operator ==(Object other) =>
      other is RateBody &&
      other.stars == stars &&
      other.comment == comment &&
      listEquals(other.reasons, reasons);

  @override
  int get hashCode => Object.hash(stars, Object.hashAll(reasons), comment);
}

/// Which hint the comment field shows, from the reasons chosen.
enum RateExample { good, bad, notFresh, wrongWeight, late, rude, many }

/// What the Customer has chosen and written on the rating screen; the
/// reasons are kept at 4 and 5 stars too, so they come back at 2 (`DL-134`).
final class RateDraft {
  const RateDraft({
    this.stars,
    this.reasons = const <RatingReason>{},
    this.comment = '',
  });

  static const RateDraft empty = RateDraft();

  final int? stars;
  final Set<RatingReason> reasons;
  final String comment;

  RateDraft copyWith({
    int? stars,
    Set<RatingReason>? reasons,
    String? comment,
  }) => RateDraft(
    stars: stars ?? this.stars,
    reasons: reasons ?? this.reasons,
    comment: comment ?? this.comment,
  );

  /// The comment's length in code points, trimmed as the server trims it.
  int get length => trimLikeServer(comment).runes.length;

  bool get tooLong => length > rateCommentMax;

  /// Whether leaving the screen should keep this: a reason or words.
  bool get worthKeeping => reasons.isNotEmpty || length > 0;

  /// The request, or `null` before a star is chosen; reasons go only with a
  /// low rating, in the server's order.
  RateBody? get body {
    final int? chosen = stars;
    if (chosen == null) {
      return null;
    }
    final String words = trimLikeServer(comment);
    return RateBody(
      stars: chosen,
      reasons: isLowRating(chosen)
          ? <RatingReason>[
              for (final RatingReason reason in RatingReason.values)
                if (reasons.contains(reason)) reason,
            ]
          : const <RatingReason>[],
      comment: words.isEmpty ? null : words,
    );
  }

  /// The example the comment field shows.
  RateExample get example {
    if (!isLowRating(stars)) {
      return RateExample.good;
    }
    if (reasons.length > 1) {
      return RateExample.many;
    }
    if (reasons.isEmpty) {
      return RateExample.bad;
    }
    return switch (reasons.first) {
      RatingReason.notFresh => RateExample.notFresh,
      RatingReason.wrongWeight => RateExample.wrongWeight,
      RatingReason.late => RateExample.late,
      RatingReason.rude => RateExample.rude,
    };
  }
}

/// The face the rating screen shows for a failed send (`DL-134`).
enum RateFailure { unsent, unsure, already, closed, notRateable, refused }

/// The face for [failure], or `null` when nothing is to be shown.
RateFailure? rateFailureOf(ApiFailure? failure) => switch (failure) {
  null || CancelledFailure() => null,
  NetworkFailure(:final bool mayHaveArrived) =>
    mayHaveArrived ? RateFailure.unsure : RateFailure.unsent,
  MalformedResponseFailure() || UnexpectedFailure() => RateFailure.unsure,
  ApiRefusal(:final int status) when status >= 500 => RateFailure.unsure,
  ApiRefusal(:final String code) => switch (code) {
    'order_already_rated' => RateFailure.already,
    'rating_window_closed' => RateFailure.closed,
    'order_not_rateable' => RateFailure.notRateable,
    _ => RateFailure.refused,
  },
};

/// The unsent ratings by order, kept while the app runs; another account
/// starts with none (`DL-134`).
class RateDrafts extends Notifier<Map<String, RateDraft>> {
  @override
  Map<String, RateDraft> build() {
    ref.watch(customerAccountProvider);
    return const <String, RateDraft>{};
  }

  /// Keeps [draft] when it is worth it; otherwise forgets the order's.
  void keep(String orderId, RateDraft draft) {
    if (draft.worthKeeping) {
      state = <String, RateDraft>{...state, orderId: draft};
    } else {
      drop(orderId);
    }
  }

  void drop(String orderId) {
    if (state.containsKey(orderId)) {
      state = <String, RateDraft>{...state}..remove(orderId);
    }
  }
}

final NotifierProvider<RateDrafts, Map<String, RateDraft>> rateDraftsProvider =
    NotifierProvider<RateDrafts, Map<String, RateDraft>>(RateDrafts.new);
