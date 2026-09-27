import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/server_text.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../addresses/application/addresses_controllers.dart';
import '../../addresses/domain/addresses.dart';
import '../application/checkout_controllers.dart';
import '../domain/checkout.dart';

/// The checkout (`docs/09` sections 18 and 19, `tasks/WAVE_2.md` W2-13):
/// an active address — or a way to add one — cash, with online shown as not
/// yet available, the delivery wish, then the server's preview of the lines,
/// fees and total and its kind, and the confirmation. What the preview was
/// asked for cannot change while it or the confirmation runs, and a change
/// afterwards drops it, so a confirmation is always of what the Customer
/// sees. A confirmation whose outcome is unknown locks the checkout until
/// the same confirmation, sent again, answers for sure (`DL-50`).
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _note;
  String? _addressId;
  PlacedOrder? _placed;

  /// Counts the Customer's changes, so an answer to what they no longer
  /// ask is not shown.
  int _revision = 0;

  /// The confirmation the last placement failure belongs to.
  String? _failedKey;

  /// The key of the preview a stale confirmation brought, while its note
  /// stands.
  String? _refreshedKey;

  @override
  void initState() {
    super.initState();
    // Back to a checkout whose confirmation is unknown: as it was sent. A
    // preview never sent is not kept — the cart may have changed since.
    final PreparedCheckout? prepared = ref.read(preparedCheckoutProvider);
    final PreparedCheckout? sent = prepared != null && prepared.sent
        ? prepared
        : null;
    _addressId = sent?.request.addressId;
    _note = TextEditingController(text: sent?.request.deliveryTimeNote ?? '');
    if (prepared != null && sent == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(preparedCheckoutProvider.notifier).clear();
        }
      });
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// What changed since the preview is not what the token confirms.
  void _changed() {
    _revision++;
    ref.read(preparedCheckoutProvider.notifier).clear();
  }

  CheckoutRequest? _request(String? address) {
    if (address == null || !_form.currentState!.validate()) {
      return null;
    }
    final String note = trimLikeServer(_note.text);
    return CheckoutRequest(
      addressId: address,
      paymentMethod: PaymentMethod.cash,
      deliveryTimeNote: note.isEmpty ? null : note,
    );
  }

  Future<void> _calculate(Address address) async {
    final CheckoutRequest? request = _request(address.id);
    if (request == null) {
      return;
    }
    final int revision = _revision;
    await ref
        .read(checkoutPreviewProvider.notifier)
        .preview(request, addressLine: _addressLine(address));
    if (mounted && revision != _revision) {
      ref.read(preparedCheckoutProvider.notifier).clear();
    }
  }

  Future<void> _confirm(PreparedCheckout prepared) async {
    setState(() {
      _failedKey = null;
      _refreshedKey = null;
    });
    final PlacedOrder? order = await ref
        .read(placeOrderProvider.notifier)
        .place(prepared);
    if (!mounted) {
      return;
    }
    if (order != null) {
      setState(() => _placed = order);
      return;
    }
    setState(() => _failedKey = prepared.idempotencyKey);
    final ApiFailure? failure = ref.read(placeOrderProvider).failure;
    if (failure is ApiRefusal && failure.code == 'checkout_snapshot_stale') {
      // A new preview — and with it a new key — of the same checkout, which
      // could not change meanwhile.
      await ref
          .read(checkoutPreviewProvider.notifier)
          .preview(prepared.request, addressLine: prepared.addressLine);
      if (!mounted) {
        return;
      }
      final PreparedCheckout? fresh = ref.read(preparedCheckoutProvider);
      if (fresh != null) {
        setState(() => _refreshedKey = fresh.idempotencyKey);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PlacedOrder? placed = _placed;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkoutTitle)),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const ActiveModeBar(),
            Expanded(
              child: placed != null
                  ? _Placed(order: placed)
                  : Form(key: _form, child: _checkout(context, l10n)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkout(BuildContext context, AppLocalizations l10n) {
    final AsyncValue<List<Address>> addresses = ref.watch(addressesProvider);
    final MutationState previewing = ref.watch(checkoutPreviewProvider);
    final MutationState placing = ref.watch(placeOrderProvider);
    final PreparedCheckout? prepared = ref.watch(preparedCheckoutProvider);
    final bool busy = previewing.isBusy || placing.isBusy;
    // A confirmation whose outcome is unknown: only it may go again.
    final bool unconfirmed = prepared?.sent ?? false;
    final bool locked = busy || unconfirmed;
    final List<Address> list = addresses.value ?? const <Address>[];
    final Address? address = list
        .where((Address a) => a.id == _addressId)
        .firstOrNull;

    return ListView(
      key: const ValueKey<String>('checkout'),
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _Heading(l10n.checkoutAddress),
        addresses.when(
          skipLoadingOnRefresh: !addresses.hasError,
          data: (List<Address> list) => _Addresses(
            addresses: list,
            selected: address?.id,
            enabled: !locked,
            onSelected: (String id) {
              setState(() => _addressId = id);
              _changed();
            },
          ),
          error: (Object error, StackTrace _) => LoadFailure(
            error: error,
            onRetry: () => ref.invalidate(addressesProvider),
          ),
          loading: () => const LinearProgressIndicator(),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey<String>('checkout-add-address'),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(l10n.checkoutAddAddress),
            onPressed: locked
                ? null
                : () => context.push(AppPaths.customerNewAddress),
          ),
        ),
        const SizedBox(height: 16),
        _Heading(l10n.checkoutPayment),
        RadioGroup<PaymentMethod>(
          groupValue: PaymentMethod.cash,
          onChanged: (PaymentMethod? _) {},
          child: Column(
            children: <Widget>[
              RadioListTile<PaymentMethod>(
                key: const ValueKey<String>('pay-cash'),
                value: PaymentMethod.cash,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.paymentCash),
              ),
              RadioListTile<PaymentMethod>(
                key: const ValueKey<String>('pay-online'),
                value: PaymentMethod.online,
                enabled: false,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.paymentOnline),
                subtitle: Text(l10n.checkoutOnlineUnavailable),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const ValueKey<String>('checkout-delivery-wish'),
          controller: _note,
          enabled: !locked,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.orderSectionDeliveryWish,
            border: const OutlineInputBorder(),
          ),
          onChanged: (String _) => _changed(),
          validator: (String? text) =>
              trimLikeServer(text ?? '').runes.length >
                  CheckoutRequest.deliveryTimeNoteMax
              ? l10n.fieldTooLong(CheckoutRequest.deliveryTimeNoteMax)
              : null,
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          key: const ValueKey<String>('checkout-calculate'),
          onPressed: locked || address == null
              ? null
              : () => _calculate(address),
          child: previewing.isBusy
              ? _Busy(label: l10n.checkoutCalculating)
              : Text(l10n.checkoutCalculate),
        ),
        CheckoutRefusal(previewing.failure),
        if (prepared != null) ...<Widget>[
          const SizedBox(height: 16),
          _Preview(prepared: prepared),
          if (_refreshedKey != null && _refreshedKey == prepared.idempotencyKey)
            _Note(
              l10n.errorCheckoutStale,
              key: const ValueKey<String>('checkout-refreshed'),
            ),
          if (unconfirmed && !placing.isBusy)
            _Note(
              l10n.checkoutUnconfirmed,
              key: const ValueKey<String>('checkout-unconfirmed'),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey<String>('checkout-confirm'),
            onPressed: busy ? null : () => _confirm(prepared),
            child: placing.isBusy
                ? _Busy(label: l10n.checkoutPlacing)
                : Text(l10n.checkoutConfirm),
          ),
        ],
        // A placement's failure stands only under the confirmation it
        // belongs to.
        if (_failedKey != null && _failedKey == prepared?.idempotencyKey)
          CheckoutRefusal(placing.failure),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

/// A notice about the checkout's state, announced when it appears.
class _Note extends StatelessWidget {
  const _Note(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );
}

class _Busy extends StatelessWidget {
  const _Busy({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 18,
    child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: label),
  );
}

String _addressLine(Address address) => '${address.street}, ${address.house}';

/// The Customer's active addresses to deliver to.
class _Addresses extends StatelessWidget {
  const _Addresses({
    required this.addresses,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final List<Address> addresses;
  final String? selected;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (addresses.isEmpty) {
      return Text(
        l10n.checkoutNoAddress,
        key: const ValueKey<String>('checkout-no-address'),
      );
    }
    return RadioGroup<String>(
      groupValue: selected,
      onChanged: (String? id) {
        if (id != null) {
          onSelected(id);
        }
      },
      child: Column(
        children: <Widget>[
          for (final Address address in addresses)
            RadioListTile<String>(
              key: ValueKey<String>('checkout-address-${address.id}'),
              value: address.id,
              enabled: enabled,
              contentPadding: EdgeInsets.zero,
              title: Text(address.label ?? _addressLine(address)),
              subtitle: address.label == null
                  ? null
                  : Text(_addressLine(address)),
            ),
        ],
      ),
    );
  }
}

/// The server's preview: where and when it goes, every line at its price,
/// the fees, the total and its kind, and when the order starts being
/// collected outside the hours.
class _Preview extends StatelessWidget {
  const _Preview({required this.prepared});

  final PreparedCheckout prepared;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final CheckoutPreview preview = prepared.preview;
    final String? opensAt = preview.opensAt;
    final String? wish = prepared.request.deliveryTimeNote;

    Widget line(String label, String amount, {Key? key, bool strong = false}) {
      final TextStyle? style = strong
          ? const TextStyle(fontWeight: FontWeight.bold)
          : null;
      return Row(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(amount, style: style, textAlign: TextAlign.end),
          ),
        ],
      );
    }

    return Card(
      key: const ValueKey<String>('checkout-preview'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '${l10n.checkoutAddress}: ${prepared.addressLine}',
              key: const ValueKey<String>('checkout-preview-address'),
            ),
            if (wish != null)
              Text(
                '${l10n.orderSectionDeliveryWish}: $wish',
                key: const ValueKey<String>('checkout-preview-wish'),
              ),
            const Divider(),
            for (final PreviewLine item in preview.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: line(
                  '${item.name(language)} · '
                  '${QuantityRules.display(item.quantity)} '
                  '${CatalogLabels.unit(l10n, item.unit)}',
                  item.priceMode == PriceMode.estimate
                      ? l10n.cartLineEstimate(
                          MoneyFormat.uzs(item.lineTotalUzs, language),
                        )
                      : MoneyFormat.uzs(item.lineTotalUzs, language),
                ),
              ),
            const Divider(),
            line(
              l10n.totalsMerchandise,
              MoneyFormat.uzs(preview.merchandiseSubtotalUzs, language),
            ),
            line(
              l10n.totalsServiceFee,
              MoneyFormat.uzs(preview.serviceFeeUzs, language),
            ),
            line(
              l10n.totalsDeliveryFee,
              MoneyFormat.uzs(preview.deliveryFeeUzs, language),
            ),
            const Divider(),
            line(
              l10n.totalsTotal,
              '${MoneyFormat.uzs(preview.totalUzs, language)} · '
              '${preview.totalKind == TotalKind.estimate ? l10n.totalKindEstimate : l10n.totalKindFinal}',
              key: const ValueKey<String>('checkout-total'),
              strong: true,
            ),
            if (preview.totalKind == TotalKind.estimate)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.checkoutEstimateExplain),
              ),
            if (preview.outsideWorkingHours && opensAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.checkoutClosedUntil(opensAt),
                  key: const ValueKey<String>('checkout-closed'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The placed order: its number and what is due, and the way back.
class _Placed extends StatelessWidget {
  const _Placed({required this.order});

  final PlacedOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final int? total = order.totalUzs;

    return ListView(
      key: const ValueKey<String>('checkout-placed'),
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Icon(
          Icons.check_circle_outline,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        // A replay answers the order as it is now: cancelled meanwhile, it
        // is said so.
        Text(
          total == null
              ? l10n.checkoutPlacedCancelled('${order.orderNumber}')
              : l10n.checkoutPlaced('${order.orderNumber}'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          total == null
              ? l10n.totalNothingDue
              : '${MoneyFormat.uzs(total, language)} · '
                    '${order.totalKind == TotalKind.estimate ? l10n.totalKindEstimate : l10n.totalKindFinal}',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey<String>('checkout-open-order'),
          onPressed: () {
            final GoRouter router = GoRouter.of(context)..go(AppPaths.customer);
            router.push(AppPaths.customerOrder(order.id));
          },
          child: Text(l10n.orderOpen),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey<String>('checkout-back-to-catalog'),
          onPressed: () => context.go(AppPaths.customer),
          child: Text(l10n.checkoutBackToCatalog),
        ),
      ],
    );
  }
}

/// A checkout refusal in words, with the values its `details` carry — the
/// minimum and the shortfall, the distances — and the way to fix it where
/// the app has one (`tasks/WAVE_2.md` W2-13).
class CheckoutRefusal extends StatelessWidget {
  const CheckoutRefusal(this.failure, {super.key});

  final ApiFailure? failure;

  /// Kilometres with two decimals, as `details` carries them.
  static final RegExp _kilometres = RegExp(r'^\d+\.\d{2}$');

  @override
  Widget build(BuildContext context) {
    final ApiFailure? failure = this.failure;
    if (failure is! ApiRefusal) {
      return FailureMessage(failure);
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Map<String, Object?> details = failure.error.details;

    Widget backToCart() => TextButton(
      key: const ValueKey<String>('checkout-back-to-cart'),
      onPressed: () => context.pop(),
      child: Text(l10n.checkoutBackToCart),
    );

    final (String? text, Widget? action) = switch (failure.code) {
      'minimum_order_not_reached' => (
        _minimum(context, l10n, details),
        backToCart(),
      ),
      'address_outside_service_area' => (_outside(l10n, details), null),
      'product_unavailable' => (
        l10n.errorCheckoutProductsUnavailable,
        backToCart(),
      ),
      'customer_profile_incomplete' => (
        l10n.errorProfileIncomplete,
        TextButton(
          key: const ValueKey<String>('checkout-open-profile'),
          onPressed: () => context.push(AppPaths.customerProfile),
          child: Text(l10n.checkoutOpenProfile),
        ),
      ),
      'resource_not_found' => (l10n.errorAddressGone, null),
      'idempotency_in_progress' => (l10n.errorOrderInProgress, null),
      _ => (null, null),
    };
    if (text == null) {
      return FailureMessage(failure);
    }
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              text,
              key: const ValueKey<String>('failure-message'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            ?action,
          ],
        ),
      ),
    );
  }

  static String _minimum(
    BuildContext context,
    AppLocalizations l10n,
    Map<String, Object?> details,
  ) {
    final Object? minimum = details['minimum_order_uzs'];
    final Object? shortfall = details['shortfall_uzs'];
    if (minimum is! int || shortfall is! int || minimum < 1 || shortfall < 1) {
      return l10n.errorMinimumOrderPlain;
    }
    final AppLanguage language = interfaceLanguage(context);
    return l10n.errorMinimumOrder(
      MoneyFormat.uzs(minimum, language),
      MoneyFormat.uzs(shortfall, language),
    );
  }

  static String _outside(AppLocalizations l10n, Map<String, Object?> details) {
    final Object? distance = details['distance_km'];
    final Object? max = details['max_distance_km'];
    return distance is String &&
            max is String &&
            _kilometres.hasMatch(distance) &&
            _kilometres.hasMatch(max)
        ? l10n.addressOutsideArea(
            distance.replaceAll('.', ','),
            max.replaceAll('.', ','),
          )
        : l10n.addressOutsideAreaPlain;
  }
}
