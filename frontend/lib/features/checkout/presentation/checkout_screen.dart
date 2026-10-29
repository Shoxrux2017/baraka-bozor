import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/server_text.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../addresses/application/addresses_controllers.dart';
import '../../addresses/application/delivery_address.dart';
import '../../addresses/domain/addresses.dart';
import '../../addresses/presentation/delivery_address_widgets.dart';
import '../../cart/application/cart_controllers.dart';
import '../../cart/domain/cart.dart';
import '../../profile/application/profile_controllers.dart';
import '../../profile/domain/profile.dart';
import '../application/checkout_controllers.dart';
import '../domain/checkout.dart';
import 'checkout_placed_view.dart';
import 'checkout_sections.dart';

/// The checkout (`docs/09` sections 18 and 19, drawings 25 to 25в): where it
/// goes, the delivery wish, cash, the goods and the amounts. The figures come
/// when the screen opens and after every change of address, and one tap on
/// "Заказать" places the order the Customer has seen: a wish typed since is
/// previewed first, and figures that came out different are shown again and
/// wait for another tap. A confirmation whose outcome is unknown locks the
/// checkout until the same confirmation, sent again, answers for sure
/// (`DL-50`).
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _note;
  final FocusNode _wishFocus = FocusNode();

  /// The wish field with its label, to bring into view (`DL-121`).
  final GlobalKey _wishKey = GlobalKey();
  final List<ProviderSubscription<dynamic>> _subscriptions =
      <ProviderSubscription<dynamic>>[];
  String? _addressId;
  PlacedOrder? _placed;

  /// When collecting starts, if the order was placed outside the hours.
  String? _placedOpensAt;

  /// The held address was chosen or restored: from now on only the Customer
  /// changes it.
  bool _adopted = false;

  /// The first frame passed: providers may be changed from now on.
  bool _started = false;

  /// An address changed while a preview ran: ask again when it is over.
  bool _previewAgain = false;

  /// An address was chosen that the loaded list does not hold yet.
  bool _previewWhenListed = false;

  /// A tap on "Заказать" is being served.
  bool _ordering = false;

  /// Previews this screen is waiting for: a run that ends while there is
  /// none came from a screen that was left.
  int _ownPreviews = 0;

  /// Counts the held address's changes, so figures for another address are
  /// never shown.
  int _revision = 0;

  /// The preview on screen: kept while the next one runs.
  CheckoutPreview? _shown;

  /// The total the Customer saw before the figures were recounted.
  int? _replacedTotal;
  ApiFailure? _failure;

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
    _adopted = sent != null;
    _shown = sent?.preview;
    // A sent confirmation shows the wish it was sent with; otherwise the
    // draft the Customer left (`DL-121`).
    _note = TextEditingController(
      text: sent != null
          ? sent.request.deliveryTimeNote ?? ''
          : ref.read(checkoutWishDraftProvider),
    );

    final String? account = ref.read(customerAccountProvider);
    if (account != null) {
      _subscriptions.add(
        ref.listenManual<AsyncValue<String?>>(
          deliveryAddressChoiceProvider(account),
          (AsyncValue<String?>? _, AsyncValue<String?> next) {
            final String? id = next.value;
            if (id != null && _adopted) {
              _pick(id);
            }
          },
        ),
      );
    }
    _subscriptions
      ..add(
        ref.listenManual<MutationState>(
          checkoutPreviewProvider,
          _foreignRunEnded,
        ),
      )
      ..add(
        ref.listenManual<MutationState>(placeOrderProvider, _foreignRunEnded),
      );
    _subscriptions.add(
      ref.listenManual<AsyncValue<List<Address>>>(
        addressesProvider,
        (AsyncValue<List<Address>>? _, AsyncValue<List<Address>> next) =>
            _addressesChanged(next),
      ),
    );
    if (_addressId == null) {
      _adoptDeliveryAddress();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void dispose() {
    for (final ProviderSubscription<dynamic> subscription in _subscriptions) {
      subscription.close();
    }
    _note.dispose();
    _wishFocus.dispose();
    super.dispose();
  }

  /// Starts from the home's delivery address (`DL-75`) once, as if the
  /// Customer had picked it: afterwards it is held like any pick, so it
  /// never moves to another address by itself when the list reloads.
  void _adoptDeliveryAddress() {
    ProviderSubscription<AsyncValue<Address?>>? subscription;
    subscription = ref.listenManual<AsyncValue<Address?>>(
      deliveryAddressProvider,
      (AsyncValue<Address?>? _, AsyncValue<Address?> next) {
        final Address? delivery = next.value;
        if (delivery == null) {
          return;
        }
        subscription?.close();
        if (mounted && _addressId == null) {
          _adoptAddress(delivery.id);
        }
      },
      fireImmediately: true,
    );
    if (_addressId != null) {
      subscription.close();
    } else {
      _subscriptions.add(subscription);
    }
  }

  /// A preview or a placement of a screen that was left ended: the figures
  /// this screen waited for are asked for now.
  void _foreignRunEnded(MutationState? previous, MutationState next) {
    if (mounted &&
        _started &&
        _previewAgain &&
        _ownPreviews == 0 &&
        !_ordering &&
        (previous?.isBusy ?? false) &&
        !next.isBusy) {
      _previewAgain = false;
      _autoPreview();
    }
  }

  void _begin() {
    if (!mounted) {
      return;
    }
    _started = true;
    final PreparedCheckout? prepared = ref.read(preparedCheckoutProvider);
    if (prepared != null && !prepared.sent) {
      ref.read(preparedCheckoutProvider.notifier).clear();
    }
    if (!_sent && _addressId != null) {
      _autoPreview();
    }
  }

  bool get _sent => ref.read(preparedCheckoutProvider)?.sent ?? false;

  Address? _heldAddress() => ref
      .read(addressesProvider)
      .value
      ?.where((Address a) => a.id == _addressId)
      .firstOrNull;

  bool _wishValid() =>
      trimLikeServer(_note.text).runes.length <=
      CheckoutRequest.deliveryTimeNoteMax;

  /// Brings the wish field into view and focuses it, so an over-long wish is
  /// seen where it is (`DL-121`).
  void _showWish() {
    final BuildContext? target = _wishKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        alignment: 0.3,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    _wishFocus.requestFocus();
  }

  CheckoutRequest _requestFor(String addressId) {
    final String wish = trimLikeServer(_note.text);
    return CheckoutRequest(
      addressId: addressId,
      paymentMethod: PaymentMethod.cash,
      deliveryTimeNote: wish.isEmpty ? null : wish,
    );
  }

  /// The Customer picked an address, in the sheet or by adding one.
  void _pick(String id) {
    if (id == _addressId || _sent || _ordering) {
      return;
    }
    _adoptAddress(id);
  }

  void _adoptAddress(String id) {
    _revision++;
    setState(() {
      _addressId = id;
      _adopted = true;
      _shown = null;
      _replacedTotal = null;
      _failure = null;
    });
    if (_started) {
      ref.read(preparedCheckoutProvider.notifier).clear();
      _autoPreview();
    }
  }

  /// The held address is no longer among the Customer's: its figures go, and
  /// no other address is taken in its place.
  void _addressesChanged(AsyncValue<List<Address>> next) {
    final List<Address>? list = next.value;
    if (list == null || next.isLoading || _addressId == null || !_started) {
      return;
    }
    final bool listed = list.any((Address a) => a.id == _addressId);
    if (!listed) {
      // A confirmation that was sent is sent as it was, whatever the list
      // holds now (`DL-50` (4)).
      _previewWhenListed = false;
      if (_sent) {
        return;
      }
      _revision++;
      ref.read(preparedCheckoutProvider.notifier).clear();
      setState(() {
        _shown = null;
        _replacedTotal = null;
      });
    } else if (_previewWhenListed) {
      _previewWhenListed = false;
      _autoPreview();
    }
  }

  /// The figures for the held address, without a tap.
  Future<void> _autoPreview() async {
    if (_sent || !_wishValid()) {
      return;
    }
    final Address? held = _heldAddress();
    if (held == null) {
      _previewWhenListed = true;
      return;
    }
    if (ref.read(checkoutPreviewProvider).isBusy ||
        ref.read(placeOrderProvider).isBusy) {
      _previewAgain = true;
      return;
    }
    await _preview(_requestFor(held.id), held.streetLine);
    if (mounted && _previewAgain) {
      _previewAgain = false;
      await _autoPreview();
    }
  }

  /// Asks for a preview; the prepared checkout when it came and is still
  /// what the Customer holds.
  Future<PreparedCheckout?> _preview(
    CheckoutRequest request,
    String addressLine,
  ) async {
    final int revision = _revision;
    setState(() => _failure = null);
    _ownPreviews++;
    try {
      await ref
          .read(checkoutPreviewProvider.notifier)
          .preview(request, addressLine: addressLine);
    } finally {
      _ownPreviews--;
    }
    if (!mounted) {
      return null;
    }
    if (revision != _revision) {
      ref.read(preparedCheckoutProvider.notifier).clear();
      return null;
    }
    final ApiFailure? failure = ref.read(checkoutPreviewProvider).failure;
    final PreparedCheckout? prepared = ref.read(preparedCheckoutProvider);
    if (failure != null) {
      _refuse(failure);
      return null;
    }
    if (prepared == null) {
      return null;
    }
    setState(() => _shown = prepared.preview);
    return prepared;
  }

  /// A refusal in the footer — or, for products gone from sale, the sheet.
  void _refuse(ApiFailure failure) {
    if (failure is ApiRefusal &&
        failure.code == 'product_unavailable' &&
        _showGone(failure)) {
      setState(() => _failure = null);
      return;
    }
    setState(() => _failure = failure);
  }

  bool _showGone(ApiRefusal refusal) {
    final Object? ids = refusal.error.details['product_ids'];
    final Set<String> gone = ids is List<Object?>
        ? ids.whereType<String>().toSet()
        : const <String>{};
    final List<CartLine> lines = <CartLine>[
      ...?ref
          .read(currentCartProvider)
          .value
          ?.lines
          .where((CartLine l) => gone.contains(l.productId)),
    ];
    if (lines.isEmpty) {
      return false;
    }
    showCheckoutGoneSheet(
      context,
      lines: lines,
      onToCart: () {
        if (mounted) {
          context.pop();
        }
      },
    );
    return true;
  }

  Future<void> _order() async {
    if (_ordering || _placed != null) {
      return;
    }
    _ordering = true;
    try {
      await _orderOnce();
    } finally {
      _ordering = false;
    }
  }

  Future<void> _orderOnce() async {
    final PreparedCheckout? prepared = ref.read(preparedCheckoutProvider);
    if (prepared != null && prepared.sent) {
      await _place(prepared);
      return;
    }
    final Address? held = _heldAddress();
    if (held == null) {
      return;
    }
    if (!(_form.currentState?.validate() ?? true) || !_wishValid()) {
      _showWish();
      return;
    }
    final CheckoutRequest request = _requestFor(held.id);
    setState(() {
      _replacedTotal = null;
      _failure = null;
    });
    // Only what the Customer has seen is placed: not a token made for
    // another request, and not figures that never reached the screen.
    if (prepared != null &&
        prepared.request == request &&
        identical(prepared.preview, _shown)) {
      await _place(prepared);
      return;
    }
    final CheckoutPreview? shown = _shown;
    final PreparedCheckout? fresh = await _preview(request, held.streetLine);
    if (fresh == null || !mounted || shown == null) {
      return;
    }
    if (fresh.preview.sameOfferAs(shown)) {
      await _place(fresh);
    } else {
      setState(() => _replacedTotal = shown.totalUzs);
    }
  }

  Future<void> _place(
    PreparedCheckout prepared, {
    bool retryStale = true,
  }) async {
    setState(() => _failure = null);
    final PlacedOrder? order = await ref
        .read(placeOrderProvider.notifier)
        .place(prepared);
    if (!mounted) {
      return;
    }
    if (order != null) {
      setState(() {
        _placed = order;
        _placedOpensAt = prepared.preview.outsideWorkingHours
            ? prepared.preview.opensAt
            : null;
      });
      return;
    }
    final ApiFailure? failure = ref.read(placeOrderProvider).failure;
    if (failure == null) {
      return;
    }
    // A refused confirmation is spent; one whose outcome is unknown stays.
    ref.read(preparedCheckoutProvider.notifier).clear();
    if (retryStale &&
        failure is ApiRefusal &&
        failure.code == 'checkout_snapshot_stale') {
      final CheckoutPreview? before = _shown;
      final PreparedCheckout? fresh = await _preview(
        prepared.request,
        prepared.addressLine,
      );
      if (fresh == null || !mounted || before == null) {
        return;
      }
      if (fresh.preview.sameOfferAs(before)) {
        await _place(fresh, retryStale: false);
      } else {
        setState(() => _replacedTotal = before.totalUzs);
      }
      return;
    }
    _refuse(failure);
  }

  /// The address sheet closed: the stored choice may differ from the held
  /// address without having changed (a tap on the marked one does not notify),
  /// and then the Customer's pick is adopted.
  Future<void> _changeAddress() async {
    await showDeliveryAddressSheet(context);
    final String? account = ref.read(customerAccountProvider);
    if (!mounted || account == null) {
      return;
    }
    final String? choice = ref
        .read(deliveryAddressChoiceProvider(account))
        .value;
    final bool listed =
        ref.read(addressesProvider).value?.any((Address a) => a.id == choice) ??
        false;
    if (choice != null && listed) {
      _pick(choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PlacedOrder? placed = _placed;
    if (placed != null) {
      return CheckoutPlacedView(order: placed, opensAt: _placedOpensAt);
    }
    final AsyncValue<List<Address>> addresses = ref.watch(addressesProvider);
    final bool busyPreview = ref.watch(checkoutPreviewProvider).isBusy;
    final bool busyPlace = ref.watch(placeOrderProvider).isBusy;
    final PreparedCheckout? prepared = ref.watch(preparedCheckoutProvider);
    final Cart? cart = ref.watch(currentCartProvider).value;
    final CustomerProfile? profile = ref.watch(profileControllerProvider).value;

    final List<Address>? list = addresses.value;
    final Address? held = list
        ?.where((Address a) => a.id == _addressId)
        .firstOrNull;
    final bool sent = prepared?.sent ?? false;
    // Gone only once the loaded list is final: not while it reloads, and not
    // before an address just picked is listed. A confirmation that was sent
    // keeps its address (`DL-50` (4)).
    final bool gone =
        _addressId != null &&
        list != null &&
        held == null &&
        !sent &&
        !addresses.isLoading &&
        !_previewWhenListed;
    final bool busy = busyPreview || busyPlace;
    final bool locked = busy || sent;
    final CheckoutPreview? shown = gone ? null : _shown;
    final String? opensAt = shown?.opensAt;

    final VoidCallback? onChange = locked
        ? null
        : addresses.hasError
        ? () => ref.invalidate(addressesProvider)
        : list == null
        ? null
        : list.isEmpty
        ? () => addDeliveryAddress(
            router: GoRouter.of(context),
            container: ProviderScope.containerOf(context),
          )
        : _changeAddress;

    final ApiFailure? failure = gone ? null : _failure;
    final List<Widget> notes = <Widget>[
      if (failure != null) CheckoutRefusal(failure),
      if (sent && !busyPlace)
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.checkoutUnconfirmed,
            key: const ValueKey<String>('checkout-unconfirmed'),
            style: const TextStyle(fontSize: 13, color: KitColors.danger),
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(title: l10n.checkoutTitle),
      bottomNavigationBar: SafeArea(
        top: false,
        child: CheckoutFooter(
          totalUzs: shown?.totalUzs,
          estimate: shown?.totalKind != TotalKind.finalTotal,
          busy: busy,
          busyLabel: busyPlace
              ? l10n.checkoutPlacing
              : l10n.checkoutCalculating,
          onOrder: sent || (!gone && held != null) ? _order : null,
          message: notes.isEmpty
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: notes,
                ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const ActiveModeBar(),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  key: const ValueKey<String>('checkout'),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: <Widget>[
                    if (shown != null &&
                        shown.outsideWorkingHours &&
                        opensAt != null) ...<Widget>[
                      CheckoutClosedBanner(opensAt: opensAt),
                      const SizedBox(height: 16),
                    ],
                    _Heading(l10n.checkoutWhere),
                    const SizedBox(height: 12),
                    CheckoutDeliveryCard(
                      address: held,
                      gone: gone,
                      sentAddressLine: sent && held == null
                          ? prepared?.addressLine
                          : null,
                      recipient: profile,
                      onChange: onChange,
                    ),
                    const SizedBox(height: 12),
                    KeyedSubtree(
                      key: _wishKey,
                      child: CheckoutWishField(
                        controller: _note,
                        focusNode: _wishFocus,
                        // Only a placement or a sent confirmation closes it:
                        // a wish typed during a preview is previewed again
                        // before placing (`DL-89`, `DL-121`).
                        enabled: !busyPlace && !sent,
                        onChanged: (String text) {
                          ref
                              .read(checkoutWishDraftProvider.notifier)
                              .set(text);
                          if (_replacedTotal != null) {
                            setState(() => _replacedTotal = null);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    _Heading(l10n.checkoutPayment),
                    const SizedBox(height: 12),
                    const CheckoutPaymentCards(),
                    if (shown != null) ...<Widget>[
                      const SizedBox(height: 24),
                      CheckoutItemsStrip(
                        lines: shown.lines,
                        imageByCartItem: <String, String?>{
                          for (final CartLine line
                              in cart?.lines ?? const <CartLine>[])
                            line.id: line.imageUrl,
                        },
                        onChange: () => context.pop(),
                      ),
                      const SizedBox(height: 16),
                      CheckoutAmounts(
                        preview: shown,
                        replacedTotalUzs: _replacedTotal,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: KitColors.ink,
      ),
    ),
  );
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
          onPressed: () => context.push(AppPaths.customerEditProfile),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            text,
            key: const ValueKey<String>('failure-message'),
            style: const TextStyle(fontSize: 13, color: KitColors.danger),
          ),
          ?action,
        ],
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
