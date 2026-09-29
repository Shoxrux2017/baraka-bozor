import 'package:baraka_bozor/core/platform/phone_calls.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The dialer's link (`DL-54` (16), `DL-69` (6)): a `tel:` link with the
/// number as the API gives it, and a phone that cannot open it answered as
/// `false`, never as an error.
void main() {
  test('the call is a tel: link to the number', () async {
    final List<Uri> opened = <Uri>[];
    final DialerPhoneCalls calls = DialerPhoneCalls(
      launch: (Uri url) async {
        opened.add(url);
        return true;
      },
    );

    expect(await calls.call('+998901112233'), isTrue);
    expect(opened.single.toString(), 'tel:+998901112233');
  });

  test('a phone that cannot open it answers false', () async {
    expect(
      await DialerPhoneCalls(launch: (Uri _) async => false)
          .call('+998901112233'),
      isFalse,
    );
    expect(
      await DialerPhoneCalls(
        launch: (Uri _) async =>
            throw PlatformException(code: 'ACTIVITY_NOT_FOUND'),
      ).call('+998901112233'),
      isFalse,
    );
  });
}
