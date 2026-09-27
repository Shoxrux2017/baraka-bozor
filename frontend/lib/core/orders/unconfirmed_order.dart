import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/customer_account.dart';

/// Whether the signed-in Customer confirmed a checkout whose outcome the
/// app could not learn — the answer was lost, or the server was still
/// placing it — so the order may exist. The checkout keeps the key to ask
/// again, which cannot place a second order (`docs/09` section 48); the
/// cart points back to it until a confirmation answers for sure. Another
/// account starts it over.
class UnconfirmedOrderController extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(customerAccountProvider);
    return false;
  }

  void set(bool unconfirmed) => state = unconfirmed;
}

final NotifierProvider<UnconfirmedOrderController, bool>
unconfirmedOrderProvider = NotifierProvider<UnconfirmedOrderController, bool>(
  UnconfirmedOrderController.new,
);
