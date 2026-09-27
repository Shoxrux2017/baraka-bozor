<?php

declare(strict_types=1);

namespace App\Modules\Orders\Checkout;

use App\Exceptions\ApiException;
use App\Models\BusinessSettings;
use App\Models\Cart;
use App\Models\CustomerAddress;
use App\Models\Enums\PaymentMethod;
use App\Models\Enums\PriceMode;
use App\Models\Enums\ServiceFeeMode;
use App\Models\User;
use App\Modules\Customer\CustomerAddresses;
use App\Modules\Orders\CartLine;
use App\Modules\Orders\CartView;
use App\Modules\Orders\QuantityPolicy;
use App\Modules\Settings\CustomerPriceCalculator;
use App\Modules\Settings\ServiceAreaPolicy;
use App\Modules\Settings\ServiceFeeCalculator;
use App\Modules\Settings\WorkingHours;
use App\Support\CanonicalJson;
use App\Support\Money\MoneyCalculator;
use App\Support\Money\Percentage;
use App\Support\Money\Quantity;
use App\Support\Scope\ScopedLookup;
use Carbon\CarbonInterface;

/**
 * Everything a checkout decides from, read once and checked in one order
 * (`docs/09` section 18, `BR-CHK-001` to `BR-CHK-009`, `DL-37` (21)): the
 * settings are complete, the Customer has a name, the address is the
 * Customer's own, complete and inside the service area, the cart has lines,
 * every line's product is available and its quantity still fits the unit, the
 * merchandise reaches the minimum, and the payment method can be taken.
 *
 * The preview builds it to show the amounts and sign them; order creation
 * builds it again under the cart lock and creates the order's snapshots from
 * it. `digest()` covers everything the order would snapshot, so a token whose
 * digest still matches promises exactly the order that will be created
 * (`DL-37` (4)).
 */
final readonly class CheckoutState
{
    /**
     * @param  list<CartLine>  $lines
     */
    private function __construct(
        public User $customer,
        public Cart $cart,
        public CustomerAddress $address,
        public PaymentMethod $paymentMethod,
        public ?string $deliveryTimeNote,
        public BusinessSettings $settings,
        public array $lines,
        public int $merchandiseSubtotalUzs,
        public int $serviceFeeUzs,
        public int $deliveryFeeUzs,
        public int $totalUzs,
        public WorkingHours $hours,
    ) {}

    public static function gather(User $customer, Cart $cart, string $addressId, PaymentMethod $paymentMethod, ?string $deliveryTimeNote): self
    {
        $settings = BusinessSettings::current();
        self::assertConfigured($settings);

        if (trim((string) $customer->full_name) === '') {
            throw ApiException::conflict('customer_profile_incomplete');
        }

        $address = ScopedLookup::firstOrNotFound(CustomerAddresses::own($customer)->whereKey($addressId));
        if (trim($address->street) === '' || trim($address->house) === '') {
            throw ApiException::conflict('address_incomplete');
        }
        ServiceAreaPolicy::assertDeliverableUnder($settings, $address->latitude, $address->longitude);

        $view = CartView::of($cart, new CustomerPriceCalculator(Percentage::fromString($settings->markup_percent)));
        if ($view->lines === []) {
            throw ApiException::conflict('cart_empty');
        }

        $unavailable = array_values(array_map(
            static fn (CartLine $line): string => $line->product->id,
            array_filter($view->lines, static fn (CartLine $line): bool => ! $line->available
                || ! QuantityPolicy::fits($line->product->unit_code, Quantity::fromString($line->item->quantity))),
        ));
        if ($unavailable !== []) {
            throw ApiException::conflict('product_unavailable', ['product_ids' => $unavailable]);
        }

        $minimum = (int) $settings->minimum_order_uzs;
        if ($view->estimatedSubtotalUzs < $minimum) {
            throw ApiException::conflict('minimum_order_not_reached', [
                'minimum_order_uzs' => $minimum,
                'shortfall_uzs' => $minimum - $view->estimatedSubtotalUzs,
            ]);
        }

        // No payment adapter exists before Wave 5 (`DL-37` (3)).
        if ($paymentMethod === PaymentMethod::Online) {
            throw ApiException::conflict('payment_method_unavailable');
        }

        $fee = (new ServiceFeeCalculator(
            $settings->service_fee_mode,
            $settings->service_fee_fixed_uzs,
            $settings->service_fee_percent,
        ))->feeOn($view->estimatedSubtotalUzs);
        $delivery = (int) $settings->delivery_fee_uzs;

        return new self(
            $customer,
            $cart,
            $address,
            $paymentMethod,
            $deliveryTimeNote,
            $settings,
            $view->lines,
            $view->estimatedSubtotalUzs,
            $fee,
            $delivery,
            MoneyCalculator::sum($view->estimatedSubtotalUzs, $fee, $delivery),
            WorkingHours::of((string) $settings->opens_at, (string) $settings->closes_at),
        );
    }

    /**
     * `final` when every line has a guaranteed price, `estimate` otherwise
     * (`BR-CHK-005`). `final` does not mean nothing can be removed.
     */
    public function totalKind(): string
    {
        foreach ($this->lines as $line) {
            if ($line->product->price_mode === PriceMode::Estimate) {
                return 'estimate';
            }
        }

        return 'final';
    }

    public function isOutsideWorkingHours(CarbonInterface $now): bool
    {
        return ! $this->hours->isOpenAt($now);
    }

    /**
     * A keyed hash over everything the order would snapshot: the recipient,
     * each line's product as it is sold now, the address, the payment method,
     * the delivery wish and the settings. Any change to any of them is a new
     * digest, and a token bound to the old one is stale.
     *
     * Keyed, because the token shows the digest to the Customer, who knows
     * every bound value but the market prices, the markup, the tolerance and
     * the delay threshold; a plain hash of a known layout would let those be
     * found by trying candidates offline (`DL-41` (7)).
     */
    public function digest(): string
    {
        $settings = $this->settings;

        return hash_hmac('sha256', CanonicalJson::encode([
            'customer' => [
                'id' => $this->customer->id,
                'name' => trim((string) $this->customer->full_name),
                'phone' => $this->customer->phone,
            ],
            'cart' => $this->cart->id,
            'lines' => array_map(static fn (CartLine $line): array => [
                'cart_item_id' => $line->item->id,
                'product_id' => $line->product->id,
                'name_uz' => $line->product->name_uz,
                'name_ru' => $line->product->name_ru,
                'unit_code' => $line->product->unit_code->value,
                'price_mode' => $line->product->price_mode->value,
                'market_price_uzs' => $line->product->market_price_uzs,
                'customer_unit_price_uzs' => $line->customerUnitPriceUzs,
                'quantity' => $line->item->quantity,
                'customer_note' => $line->item->customer_note,
                'substitution_policy' => $line->item->substitution_policy->value,
            ], $this->lines),
            'address' => [
                'id' => $this->address->id,
                'latitude' => $this->address->latitude,
                'longitude' => $this->address->longitude,
                'street' => $this->address->street,
                'house' => $this->address->house,
                'apartment' => $this->address->apartment,
                'landmark' => $this->address->landmark,
                'delivery_note' => $this->address->delivery_note,
            ],
            'payment_method' => $this->paymentMethod->value,
            'delivery_time_note' => $this->deliveryTimeNote,
            'settings' => [
                'markup_percent' => $settings->markup_percent,
                'price_tolerance_percent' => $settings->price_tolerance_percent,
                'service_fee_mode' => $settings->service_fee_mode->value,
                'service_fee_fixed_uzs' => $settings->service_fee_fixed_uzs,
                'service_fee_percent' => $settings->service_fee_percent,
                'delivery_fee_uzs' => $settings->delivery_fee_uzs,
                'delivery_delay_threshold_minutes' => $settings->delivery_delay_threshold_minutes,
            ],
        ]), CheckoutSecrets::key(CheckoutSecrets::DIGEST));
    }

    /**
     * `BR-SET-002`: checkout waits until every setting it needs exists — the
     * fee of the chosen mode, the delivery fee, the minimum, the working
     * hours and the service area.
     */
    private static function assertConfigured(BusinessSettings $settings): void
    {
        $feeValue = $settings->service_fee_mode === ServiceFeeMode::Fixed
            ? $settings->service_fee_fixed_uzs
            : $settings->service_fee_percent;

        foreach ([
            $feeValue,
            $settings->delivery_fee_uzs,
            $settings->minimum_order_uzs,
            $settings->opens_at,
            $settings->closes_at,
            $settings->service_centre_latitude,
            $settings->service_centre_longitude,
            $settings->service_radius_km,
        ] as $value) {
            if ($value === null) {
                throw ApiException::conflict('checkout_configuration_incomplete');
            }
        }
    }
}
