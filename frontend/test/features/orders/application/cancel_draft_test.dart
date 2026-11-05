import 'dart:ui';

import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/orders/application/cancel_draft.dart';
import 'package:baraka_bozor/features/orders/data/customer_orders_api.dart';
import 'package:baraka_bozor/features/orders/domain/customer_orders.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_customer_orders_repository.dart';

final AppLocalizations _ru = lookupAppLocalizations(const Locale('ru'));

String _compose(CancelChip? chip, String text) => composeCancelReason(
  CancelDraft(chip: chip, text: text),
  (CancelChip c) => cancelChipLabel(_ru, c),
);

CustomerOrder _order({bool direct = false, bool request = false}) =>
    CustomerOrdersApi.parseOrder(<String, Object?>{
      ...customerOrderJson(canRequestCancellation: request),
      'can_cancel_directly': direct,
    });

void main() {
  test('a chip is the reason, with details after a colon', () {
    expect(
      _compose(CancelChip.wrongItems, ' не тот размер '),
      'Заказал не то: не тот размер',
    );
    expect(_compose(CancelChip.wrongItems, ''), 'Заказал не то');
    expect(_compose(null, ' Долго '), 'Долго');
    expect(_compose(CancelChip.other, ''), '');
    expect(_compose(CancelChip.other, 'x'), 'x');
  });

  test('the limit counts runes of the whole reason', () {
    expect(cancelBlock('a' * 300, request: false), isNull);
    expect(cancelBlock('a' * 301, request: false), CancelBlock.tooLong);
    expect(cancelBlock('a' * 301, request: true), CancelBlock.tooLong);
    expect(cancelBlock('${'a' * 299}😀', request: false), isNull);
    expect(cancelBlock('${'a' * 300}😀', request: false), CancelBlock.tooLong);
  });

  test('only a request needs a reason', () {
    expect(cancelBlock('', request: true), CancelBlock.empty);
    expect(cancelBlock('', request: false), isNull);
    expect(cancelBlock('почему', request: true), isNull);
  });

  test('retry beats every other face', () {
    expect(
      cancelSheetMode(
        _order(direct: true, request: true),
        unconfirmed: true,
        forcedRequest: false,
      ),
      CancelSheetMode.retry,
    );
    expect(
      cancelSheetMode(_order(), unconfirmed: true, forcedRequest: true),
      CancelSheetMode.retry,
    );
    expect(
      cancelSheetMode(
        _order(direct: true),
        unconfirmed: false,
        forcedRequest: false,
      ),
      CancelSheetMode.direct,
    );
    expect(
      cancelSheetMode(
        _order(request: true),
        unconfirmed: false,
        forcedRequest: false,
      ),
      CancelSheetMode.request,
    );
  });

  test('a 422 turns a direct order into a request', () {
    expect(
      cancelSheetMode(
        _order(direct: true),
        unconfirmed: false,
        forcedRequest: true,
      ),
      CancelSheetMode.request,
    );
    const ApiRefusal refusal = ApiRefusal(
      ApiError(
        status: 422,
        code: 'validation_failed',
        errors: <String, List<String>>{
          'reason': <String>['x'],
        },
      ),
    );
    expect(cancelNeedsReason(refusal), isTrue);
    expect(cancelNeedsReason(const NetworkFailure()), isFalse);
    expect(cancelNeedsReason(null), isFalse);
    expect(
      cancelNeedsReason(const ApiRefusal(ApiError(status: 409, code: 'x'))),
      isFalse,
    );
  });

  test('an order that allows neither is closed', () {
    expect(
      cancelSheetMode(_order(), unconfirmed: false, forcedRequest: false),
      CancelSheetMode.closed,
    );
    expect(
      cancelSheetMode(_order(), unconfirmed: false, forcedRequest: true),
      CancelSheetMode.closed,
    );
  });

  test('the draft has value equality and knows when it is empty', () {
    expect(CancelDraft.empty.isEmpty, isTrue);
    expect(
      const CancelDraft(chip: CancelChip.tooSlow),
      const CancelDraft(chip: CancelChip.tooSlow),
    );
    expect(const CancelDraft(text: 'a').isEmpty, isFalse);
    expect(CancelDraft.empty.copyWith(details: true).details, isTrue);
  });
}
