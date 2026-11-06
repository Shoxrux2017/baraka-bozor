import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/orders/application/rate_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Account extends Notifier<String?> {
  @override
  String? build() => 'a';

  void signIn(String? id) => state = id;
}

final NotifierProvider<_Account, String?> _account =
    NotifierProvider<_Account, String?>(_Account.new);

ProviderContainer _container() {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      customerAccountProvider.overrideWith((Ref ref) => ref.watch(_account)),
    ],
  );
  container.listen(rateDraftsProvider, (_, _) {});
  return container;
}

ApiRefusal _refusal(int status, String code) =>
    ApiRefusal(ApiError(status: status, code: code));

void main() {
  test('the body sends reasons only at 1 to 3, in order', () {
    expect(
      const RateDraft(
        stars: 2,
        reasons: <RatingReason>{RatingReason.late, RatingReason.notFresh},
      ).body,
      const RateBody(
        stars: 2,
        reasons: <RatingReason>[RatingReason.notFresh, RatingReason.late],
        comment: null,
      ),
    );
    expect(
      const RateDraft(
        stars: 5,
        reasons: <RatingReason>{RatingReason.late},
      ).body!.reasons,
      isEmpty,
    );
    expect(const RateDraft(stars: 4, comment: '  да ').body!.comment, 'да');
    expect(const RateDraft(stars: 4, comment: '   ').body!.comment, isNull);
    expect(const RateDraft(comment: 'да').body, isNull);
    expect(isLowRating(3), isTrue);
    expect(isLowRating(4), isFalse);
    expect(isLowRating(null), isFalse);
  });

  test('length counts code points of the trimmed comment', () {
    expect(const RateDraft(comment: ' 🍅🍅 ').length, 2);
    expect(RateDraft(comment: 'а' * 500).tooLong, isFalse);
    expect(RateDraft(comment: 'а' * 501).tooLong, isTrue);
  });

  test('the example follows the reasons', () {
    expect(const RateDraft(stars: 5).example, RateExample.good);
    expect(const RateDraft(stars: 2).example, RateExample.bad);
    expect(
      const RateDraft(
        stars: 2,
        reasons: <RatingReason>{RatingReason.wrongWeight},
      ).example,
      RateExample.wrongWeight,
    );
    expect(
      const RateDraft(
        stars: 2,
        reasons: <RatingReason>{RatingReason.late, RatingReason.rude},
      ).example,
      RateExample.many,
    );
  });

  test('failures map to faces', () {
    expect(rateFailureOf(null), isNull);
    expect(rateFailureOf(const CancelledFailure()), isNull);
    expect(
      rateFailureOf(const NetworkFailure(mayHaveArrived: false)),
      RateFailure.unsent,
    );
    expect(rateFailureOf(const NetworkFailure()), RateFailure.unsure);
    expect(rateFailureOf(const MalformedResponseFailure()), RateFailure.unsure);
    expect(rateFailureOf(const UnexpectedFailure()), RateFailure.unsure);
    expect(rateFailureOf(_refusal(503, 'server_error')), RateFailure.unsure);
    expect(
      rateFailureOf(_refusal(409, 'order_already_rated')),
      RateFailure.already,
    );
    expect(
      rateFailureOf(_refusal(409, 'rating_window_closed')),
      RateFailure.closed,
    );
    expect(
      rateFailureOf(_refusal(409, 'order_not_rateable')),
      RateFailure.notRateable,
    );
    expect(
      rateFailureOf(_refusal(422, 'validation_failed')),
      RateFailure.refused,
    );
  });

  test('a draft is kept only with a reason or words', () {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    final RateDrafts drafts = container.read(rateDraftsProvider.notifier);

    drafts.keep('o1', const RateDraft(stars: 3));
    expect(container.read(rateDraftsProvider), isEmpty);

    drafts.keep('o1', const RateDraft(stars: 3, comment: '  '));
    expect(container.read(rateDraftsProvider), isEmpty);

    drafts.keep('o1', const RateDraft(stars: 3, comment: 'долго'));
    expect(container.read(rateDraftsProvider).keys, <String>['o1']);

    drafts.keep(
      'o2',
      const RateDraft(stars: 2, reasons: <RatingReason>{RatingReason.rude}),
    );
    expect(container.read(rateDraftsProvider).keys, <String>['o1', 'o2']);

    drafts.keep('o1', const RateDraft(stars: 3));
    expect(container.read(rateDraftsProvider).keys, <String>['o2']);
  });

  test('another account starts with no drafts', () {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    container
        .read(rateDraftsProvider.notifier)
        .keep('o1', const RateDraft(stars: 2, comment: 'плохо'));
    expect(container.read(rateDraftsProvider), isNotEmpty);

    container.read(_account.notifier).signIn('b');

    expect(container.read(rateDraftsProvider), isEmpty);
  });

  test("drop removes the order's draft", () {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    final RateDrafts drafts = container.read(rateDraftsProvider.notifier)
      ..keep('o1', const RateDraft(stars: 2, comment: 'a'))
      ..keep('o2', const RateDraft(stars: 2, comment: 'b'))
      ..drop('o1');
    expect(container.read(rateDraftsProvider).keys, <String>['o2']);
    drafts.drop('missing');
    expect(container.read(rateDraftsProvider).keys, <String>['o2']);
  });

  test('copyWith sets stars and keeps the rest', () {
    const RateDraft draft = RateDraft(comment: 'x');
    final RateDraft next = draft.copyWith(stars: 4);
    expect(next.stars, 4);
    expect(next.comment, 'x');
    expect(RateDraft.empty.worthKeeping, isFalse);
  });
}
