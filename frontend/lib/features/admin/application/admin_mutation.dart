import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/staff_account.dart';
import '../../../core/state/account_mutation.dart';

/// A change the Admin makes in the panel: an [AccountMutation] for the
/// staff account, the base of every catalog and staff controller.
abstract class AdminMutation extends AccountMutation {
  @override
  Provider<String?> get account => staffAccountProvider;
}
