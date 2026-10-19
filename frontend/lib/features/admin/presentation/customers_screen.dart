import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/admin_customers_controllers.dart';
import '../domain/admin_customers.dart';

/// The Admin's Customer accounts (`docs/09-api-contracts.md` sections 66
/// and 67): the accounts on the number a caller rang from, and the erasure
/// of one of them on request.
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  static final RegExp _phone = RegExp(r'^\+998\d{9}$');

  final TextEditingController _phoneField = TextEditingController();
  bool _malformed = false;

  @override
  void dispose() {
    _phoneField.dispose();
    super.dispose();
  }

  void _find() {
    final String phone = _phoneField.text.trim();
    if (!_phone.hasMatch(phone)) {
      setState(() => _malformed = true);
      return;
    }
    setState(() => _malformed = false);
    ref.read(customerSearchProvider.notifier).find(phone);
  }

  Future<void> _erase(AdminCustomer customer) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.customerEraseTitle),
        content: Text(l10n.customerEraseBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: const ValueKey<String>('customer-erase-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.customerEraseConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final bool erased = await ref
        .read(eraseCustomerControllerProvider.notifier)
        .erase(customer.id);
    if (erased) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.customerErased)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<AdminCustomer>>? found = ref.watch(
      customerSearchProvider,
    );
    final MutationState erasing = ref.watch(eraseCustomerControllerProvider);
    final ApiFailure? failure = erasing.failure;
    final ({String id, int number})? blockedBy = failure?.unfinishedOrder;

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Text(
              l10n.customersTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const ValueKey<String>('customers-phone'),
                    controller: _phoneField,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (String _) => _find(),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: '+998901234567',
                      errorText: _malformed ? l10n.customersPhoneHint : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  key: const ValueKey<String>('customers-find'),
                  onPressed: _find,
                  child: Text(l10n.customersFind),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (blockedBy != null)
              Text(
                l10n.customerUnfinished('${blockedBy.number}'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else
              FailureMessage(failure),
            if (found != null)
              found.when(
                skipLoadingOnReload: false,
                skipLoadingOnRefresh: !found.hasError,
                data: (List<AdminCustomer> customers) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (customers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l10n.customersNone),
                      ),
                    for (final AdminCustomer customer in customers)
                      _CustomerCard(
                        customer: customer,
                        busy: erasing.isBusy,
                        onErase: () => _erase(customer),
                      ),
                  ],
                ),
                error: (Object error, StackTrace _) => FailureMessage(
                  error is ApiFailure ? error : const UnexpectedFailure(),
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.busy,
    required this.onErase,
  });

  final AdminCustomer customer;
  final bool busy;
  final VoidCallback onErase;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ({String id, int number})? unfinished = customer.unfinishedOrder;

    return Card(
      key: ValueKey<String>('customer-${customer.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              customer.fullName ?? l10n.customerNoName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(formatPhone(customer.phone)),
            Text(customer.isBlocked ? l10n.statusBlocked : l10n.statusActive),
            Text(l10n.customerOrders(customer.orderCount)),
            if (unfinished != null)
              Text(l10n.customerUnfinished('${unfinished.number}')),
            const SizedBox(height: 12),
            OutlinedButton(
              key: ValueKey<String>('customer-erase-${customer.id}'),
              onPressed: unfinished != null || busy ? null : onErase,
              child: Text(l10n.customerErase),
            ),
          ],
        ),
      ),
    );
  }
}
