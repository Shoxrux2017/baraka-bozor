<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Models\Enums\CartStatus;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\User;
use App\Modules\Orders\CartLine;
use App\Modules\Orders\Checkout\CheckoutState;
use App\Modules\Orders\Checkout\CheckoutToken;
use App\Modules\Orders\CustomerCart;
use App\Modules\Orders\CustomerOrders;
use App\Support\Idempotency\IdempotencyStore;
use App\Support\Idempotency\RequestFingerprint;
use App\Support\Scope\ScopedLookup;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * `POST /customer/orders` (`docs/09` section 19, `docs/04` section 8,
 * `BR-CHK-006` to `BR-CHK-008`).
 *
 * Idempotent (`DL-39`): a retry with the same key and token answers the order
 * the first request created, loaded through the Customer's own orders. The
 * operation, in the transaction that completes the key:
 *
 * 1. reads the token — anything wrong with it is `checkout_snapshot_stale`;
 * 2. locks the Customer's active cart (`DL-37` (7)); a cart other than the
 *    token's has been converted since, and the token is stale;
 * 3. checks the checkout again from the locked cart and one reading of the
 *    settings, and compares its digest with the token's — any difference is
 *    stale, and the Customer previews again;
 * 4. creates the order with every snapshot taken from those same values, its
 *    lines, the first history row, converts the cart and opens a new empty
 *    one (`BR-CHK-008`).
 *
 * No push is sent in this wave (`DL-37` (15)).
 */
final class CreateOrder
{
    public const OPERATION = 'orders.create';

    public function __construct(private readonly IdempotencyStore $idempotency) {}

    public function create(User $customer, string $token, string $idempotencyKey): Order
    {
        return $this->idempotency->run(
            $customer->id,
            self::OPERATION,
            $idempotencyKey,
            RequestFingerprint::of(self::OPERATION, [], ['checkout_token' => $token]),
            fn (): Order => $this->place($customer, $token),
            static fn (string $orderId): Order => ScopedLookup::firstOrNotFound(CustomerOrders::own($customer)->whereKey($orderId)),
        );
    }

    private function place(User $customer, string $token): Order
    {
        $claims = CheckoutToken::read($token, $customer, now());
        $cart = CustomerCart::lock($customer);

        if ($cart->id !== $claims->cartId) {
            throw CheckoutToken::stale();
        }

        $state = CheckoutState::gather($customer, $cart, $claims->addressId, $claims->paymentMethod, $claims->deliveryTimeNote);

        if (! hash_equals($claims->digest, $state->digest())) {
            throw CheckoutToken::stale();
        }

        $order = $this->order($state);
        foreach ($state->lines as $line) {
            $this->line($order, $line, $state->settings->markup_percent);
        }

        $history = new OrderHistory;
        $history->forceFill([
            'order_id' => $order->id,
            'event_type' => OrderHistoryEvent::StatusChanged,
            'from_status' => null,
            'to_status' => OrderStatus::New,
            'actor_type' => HistoryActorType::User,
            'actor_user_id' => $customer->id,
        ])->save();

        $cart->status = CartStatus::Converted;
        $cart->save();
        DB::table('carts')->insert([
            'id' => (string) Str::uuid(),
            'customer_id' => $customer->id,
            'status' => CartStatus::Active->value,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // The order number comes from its sequence; the insert does not
        // return it.
        return $order->refresh();
    }

    private function order(CheckoutState $state): Order
    {
        $settings = $state->settings;
        $address = $state->address;

        $order = new Order;
        $order->forceFill([
            'customer_id' => $state->customer->id,
            'source_cart_id' => $state->cart->id,
            'source_address_id' => $address->id,
            'status' => OrderStatus::New,
            'payment_method' => $state->paymentMethod,
            'delivery_time_note' => $state->deliveryTimeNote,
            'recipient_name_snapshot' => trim((string) $state->customer->full_name),
            'recipient_phone_snapshot' => $state->customer->phone,
            'latitude_snapshot' => $address->latitude,
            'longitude_snapshot' => $address->longitude,
            'street_snapshot' => $address->street,
            'house_snapshot' => $address->house,
            'apartment_snapshot' => $address->apartment,
            'landmark_snapshot' => $address->landmark,
            'delivery_note_snapshot' => $address->delivery_note,
            'markup_percent_snapshot' => $settings->markup_percent,
            'price_tolerance_percent_snapshot' => $settings->price_tolerance_percent,
            'service_fee_mode_snapshot' => $settings->service_fee_mode,
            'service_fee_fixed_uzs_snapshot' => $settings->service_fee_fixed_uzs,
            'service_fee_percent_snapshot' => $settings->service_fee_percent,
            'delivery_fee_uzs_snapshot' => $settings->delivery_fee_uzs,
            'delivery_delay_threshold_minutes_snapshot' => $settings->delivery_delay_threshold_minutes,
        ])->save();

        return $order;
    }

    private function line(Order $order, CartLine $line, string $markupPercent): void
    {
        $product = $line->product;

        $item = new OrderItem;
        $item->forceFill([
            'order_id' => $order->id,
            'product_id' => $product->id,
            'product_name_uz_snapshot' => $product->name_uz,
            'product_name_ru_snapshot' => $product->name_ru,
            'unit_code_snapshot' => $product->unit_code,
            'price_mode_snapshot' => $product->price_mode,
            'market_price_uzs_snapshot' => $product->market_price_uzs,
            'customer_unit_price_uzs_snapshot' => $line->customerUnitPriceUzs,
            'markup_percent_snapshot' => $markupPercent,
            'ordered_quantity' => $line->item->quantity,
            'billable_quantity' => '0.000',
            'customer_note_snapshot' => $line->item->customer_note,
            'substitution_policy_snapshot' => $line->item->substitution_policy,
            'status' => OrderItemStatus::Pending,
        ])->save();
    }
}
