import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The welcome a new Customer is owed once the home opens (`DL-139`).
final class Welcome {
  const Welcome({required this.accountId, required this.name});

  /// The account the name was given for.
  final String accountId;
  final String name;
}

/// Holds one [Welcome] from the name step to the home. The home takes it, so
/// the strip shows once, and only for the account it was meant for.
class WelcomeNotice extends Notifier<Welcome?> {
  @override
  Welcome? build() => null;

  void show(Welcome welcome) => state = welcome;

  /// Returns the notice and clears it when it is for [accountId]. A notice for
  /// another account is cleared and nothing is returned.
  Welcome? take(String accountId) {
    final Welcome? held = state;
    if (held == null) {
      return null;
    }
    state = null;
    return held.accountId == accountId ? held : null;
  }
}

final NotifierProvider<WelcomeNotice, Welcome?> welcomeNoticeProvider =
    NotifierProvider<WelcomeNotice, Welcome?>(WelcomeNotice.new);
