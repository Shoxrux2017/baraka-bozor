import 'package:baraka_bozor/core/formatting/tashkent_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the date is the Tashkent day', () {
    expect(TashkentTime.date(DateTime.utc(2026, 10, 18, 20, 30)), '19.10.2026');
    expect(TashkentTime.date(DateTime.utc(2026, 10, 18, 18, 59)), '18.10.2026');
  });
}
