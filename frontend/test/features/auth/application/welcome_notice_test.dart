import 'package:baraka_bozor/features/auth/application/welcome_notice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  WelcomeNotice notice() => container.read(welcomeNoticeProvider.notifier);

  test('a notice is taken once, by its own account', () {
    notice().show(const Welcome(accountId: 'c', name: 'Aziza'));

    final Welcome? first = notice().take('c');
    expect(first?.name, 'Aziza');
    expect(notice().take('c'), isNull);
    expect(container.read(welcomeNoticeProvider), isNull);
  });

  test('another account gets nothing and the notice is dropped', () {
    notice().show(const Welcome(accountId: 'c', name: 'Aziza'));

    expect(notice().take('other'), isNull);
    expect(container.read(welcomeNoticeProvider), isNull);
    expect(notice().take('c'), isNull);
  });
}
