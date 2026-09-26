import 'package:baraka_bozor/core/network/api_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unwrap takes the data member of the docs/09 section 2 envelope', () {
    expect(ApiEnvelope.unwrap(<String, Object?>{'data': 1}), 1);
    expect(
      ApiEnvelope.unwrap(<String, Object?>{
        'data': <Object?>[],
        'meta': <String, Object?>{'total': 0},
      }),
      <Object?>[],
    );
  });

  test('anything that is not an envelope is a failure, never a default', () {
    expect(
      () => ApiEnvelope.unwrap(<String, Object?>{'meta': 1}),
      throwsFormatException,
    );
    expect(() => ApiEnvelope.unwrap('<html>'), throwsFormatException);
    expect(() => ApiEnvelope.unwrap(null), throwsFormatException);
  });
}
