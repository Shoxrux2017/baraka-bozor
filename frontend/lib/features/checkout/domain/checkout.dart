import '../../../core/catalog/catalog_values.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/orders/order_values.dart';

/// What the Customer asks the checkout for (`docs/09` section 18).
final class CheckoutRequest {
  const CheckoutRequest({
    required this.addressId,
    required this.paymentMethod,
    required this.deliveryTimeNote,
  });

  /// The longest delivery wish the API takes.
  static const int deliveryTimeNoteMax = 160;

  final String addressId;
  final PaymentMethod paymentMethod;
  final String? deliveryTimeNote;
}

/// One line of the preview, at the price the order would take.
final class PreviewLine {
  const PreviewLine({
    required this.cartItemId,
    required this.productId,
    required this.nameUz,
    required this.nameRu,
    required this.unit,
    required this.quantity,
    required this.priceMode,
    required this.customerUnitPriceUzs,
    required this.lineTotalUzs,
  });

  final String cartItemId;
  final String productId;
  final String nameUz;
  final String nameRu;
  final UnitCode unit;

  /// A decimal string, as the API gives it.
  final String quantity;
  final PriceMode priceMode;
  final int customerUnitPriceUzs;
  final int lineTotalUzs;

  String name(AppLanguage language) =>
      language == AppLanguage.ru ? nameRu : nameUz;
}

/// The checkout as the server computed it, with the token that confirms
/// exactly it for five minutes (`DL-37` (4)).
final class CheckoutPreview {
  const CheckoutPreview({
    required this.lines,
    required this.merchandiseSubtotalUzs,
    required this.serviceFeeUzs,
    required this.deliveryFeeUzs,
    required this.totalUzs,
    required this.totalKind,
    required this.paymentMethod,
    required this.deliveryTimeNote,
    required this.outsideWorkingHours,
    required this.opensAt,
    required this.token,
    required this.tokenExpiresAt,
  });

  final List<PreviewLine> lines;
  final int merchandiseSubtotalUzs;
  final int serviceFeeUzs;
  final int deliveryFeeUzs;
  final int totalUzs;

  /// `estimate` or `final`, never `none`.
  final TotalKind totalKind;
  final PaymentMethod paymentMethod;
  final String? deliveryTimeNote;

  /// Placed now, the order waits for the working hours to be collected.
  final bool outsideWorkingHours;

  /// `HH:MM` in `Asia/Tashkent`; `null` when the business is always open.
  final String? opensAt;
  final String token;
  final DateTime tokenExpiresAt;
}

/// A preview ready to confirm, with the key its confirmation is sent under.
/// The key is new for every preview and the same for every retry of that
/// preview's confirmation (`tasks/WAVE_2.md` W2-13, `docs/09` section 48).
final class PreparedCheckout {
  const PreparedCheckout({
    required this.request,
    required this.preview,
    required this.idempotencyKey,
  });

  final CheckoutRequest request;
  final CheckoutPreview preview;
  final String idempotencyKey;
}

/// The order a confirmation placed.
final class PlacedOrder {
  const PlacedOrder({
    required this.id,
    required this.orderNumber,
    required this.totalUzs,
    required this.totalKind,
  });

  final String id;
  final int orderNumber;
  final int totalUzs;
  final TotalKind totalKind;
}

/// The Customer's checkout (`docs/09` sections 18 and 19), on the Customer
/// session. Every method throws an `ApiFailure`.
abstract interface class CheckoutRepository {
  Future<CheckoutPreview> preview(CheckoutRequest request);

  /// Places the order [token] confirms, under [idempotencyKey].
  Future<PlacedOrder> place(String token, String idempotencyKey);
}
