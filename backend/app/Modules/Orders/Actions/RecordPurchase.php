<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\PriceMode;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\User;
use App\Modules\Orders\PriceBound;
use App\Modules\Orders\QuantityPolicy;
use App\Modules\Orders\ShopperLine;
use App\Modules\Orders\ShopperOrders;
use App\Support\Idempotency\IdempotencyStore;
use App\Support\Idempotency\RequestFingerprint;
use App\Support\Money\MoneyCalculator;
use App\Support\Money\Percentage;
use App\Support\Money\Quantity;
use App\Support\Scope\ScopedLookup;
use Illuminate\Validation\ValidationException;

/**
 * `POST /shopper/orders/{order}/items/{item}/purchase` (`docs/09` section 30,
 * `docs/04` sections 13 to 15, `DL-54` (4), `DL-57`).
 *
 * Idempotent (`DL-39`). Under the order lock, on a `pending` line of an order
 * being shopped by the caller (`ShopperLine`):
 *
 * - **What was bought.** The line's own product or the replacement
 *   authorized on it; left out, the replacement when there is one. Buying the
 *   original drops the replacement's authorization and its approved price,
 *   and copies the original's names and unit from the line, not from the
 *   catalog (`DL-55` (12)).
 * - **How much.** The billable quantity is the ordered quantity, or an
 *   approved cap: the excess is never billed (`BR-QTY-003`, `BR-QTY-004`). A
 *   purchase below it is a reduction the Customer has not agreed to
 *   (`BR-QTY-005`): `409 customer_approval_required`, `reduced_quantity`.
 * - **At what price.** A fixed original bought as itself is billed at its
 *   snapshot, and may record the price paid (`BR-PRICE-002`). An estimate
 *   original and every replacement need the price paid and are billed at
 *   `half_up(price × (1 + line markup / 100))` (`BR-PRICE-003`,
 *   `BR-PRICE-004`), within the bound of the product bought (`DL-54` (5));
 *   above it, `409 customer_approval_required`, `price_over_tolerance`.
 *
 * The line becomes `purchased` with its total (`BR-MONEY-003`), and one
 * `item_purchased` history row records it (`DL-54` (23)).
 */
final class RecordPurchase
{
    public const OPERATION = 'shopper.purchase';

    public function __construct(private readonly IdempotencyStore $idempotency) {}

    /**
     * @param  array{purchased_quantity: string, actual_market_price_uzs?: int|null, fulfilled_product_id?: string|null}  $body
     */
    public function purchase(User $shopper, string $orderId, string $itemId, array $body, string $idempotencyKey): Order
    {
        return $this->idempotency->run(
            $shopper->id,
            self::OPERATION,
            $idempotencyKey,
            RequestFingerprint::of(self::OPERATION, ['order' => $orderId, 'item' => $itemId], self::asRequested($body)),
            fn (): Order => $this->purchaseNow($shopper, $orderId, $itemId, $body),
            static fn (string $id): Order => ScopedLookup::firstOrNotFound(ShopperOrders::current($shopper)->whereKey($id)),
        );
    }

    /**
     * @param  array{purchased_quantity: string, actual_market_price_uzs?: int|null, fulfilled_product_id?: string|null}  $body
     */
    private function purchaseNow(User $shopper, string $orderId, string $itemId, array $body): Order
    {
        [$order, , $line] = ShopperLine::lockPending($shopper, $orderId, $itemId);

        $purchased = QuantityPolicy::parse($line->unit_code_snapshot, $body['purchased_quantity'], 'purchased_quantity');
        $replacement = ShopperLine::replacementOf($line);
        $bought = $this->boughtProduct($line, $replacement, $body['fulfilled_product_id'] ?? null);
        $asReplacement = $bought !== $line->product_id;
        $actual = $body['actual_market_price_uzs'] ?? null;

        if (($asReplacement || $line->price_mode_snapshot === PriceMode::Estimate) && $actual === null) {
            throw ValidationException::withMessages([
                'actual_market_price_uzs' => 'The price paid is required for an estimate line and a replacement.',
            ]);
        }

        $billableQuantity = Quantity::fromString($line->approved_quantity_cap ?? $line->ordered_quantity);
        if ($purchased->thousandths < $billableQuantity->thousandths) {
            throw ApiException::conflict('customer_approval_required', [
                'approval_type' => 'reduced_quantity',
                'required_quantity' => QuantityPolicy::format($line->unit_code_snapshot, $billableQuantity->toDecimal()),
            ]);
        }

        $billablePrice = $this->billablePrice($line, $order, $asReplacement, $actual);

        $lineTotal = MoneyCalculator::lineTotal($billablePrice, $billableQuantity);
        $line->forceFill([
            'status' => OrderItemStatus::Purchased,
            'purchased_quantity' => $purchased->toDecimal(),
            'billable_quantity' => $billableQuantity->toDecimal(),
            'actual_market_price_uzs' => $actual,
            'billable_unit_price_uzs' => $billablePrice,
            'line_total_uzs' => $lineTotal,
        ]);
        if (! $asReplacement) {
            $line->forceFill([
                'fulfilled_product_id' => $line->product_id,
                'fulfilled_product_name_uz_snapshot' => $line->product_name_uz_snapshot,
                'fulfilled_product_name_ru_snapshot' => $line->product_name_ru_snapshot,
                'fulfilled_unit_code_snapshot' => $line->unit_code_snapshot,
                'substitution_resolution' => null,
                'approved_replacement_price_uzs' => null,
            ]);
        }
        $line->save();

        $history = new OrderHistory;
        $history->forceFill([
            'order_id' => $order->id,
            'event_type' => OrderHistoryEvent::ItemPurchased,
            'actor_type' => HistoryActorType::User,
            'actor_user_id' => $shopper->id,
            'details' => [
                'item_id' => $line->id,
                'product_id' => $bought,
                'purchased_quantity' => $purchased->toDecimal(),
                'billable_quantity' => $billableQuantity->toDecimal(),
                'actual_market_price_uzs' => $actual,
                'billable_unit_price_uzs' => $billablePrice,
                'line_total_uzs' => $lineTotal,
            ],
        ])->save();

        return $order;
    }

    /**
     * The request as the fingerprint compares it (`DL-39` (7), `DL-57` (5)):
     * one purchase whether the quantity is written `"2"` or `"2.000"`, the id
     * in either case, and the price absent or `null`.
     *
     * @param  array{purchased_quantity: string, actual_market_price_uzs?: int|null, fulfilled_product_id?: string|null}  $body
     * @return array{purchased_quantity: string, actual_market_price_uzs: int|null, fulfilled_product_id: string|null}
     */
    private static function asRequested(array $body): array
    {
        $quantity = $body['purchased_quantity'];
        $named = $body['fulfilled_product_id'] ?? null;

        return [
            'purchased_quantity' => preg_match('/^\d{1,4}(\.\d{1,3})?\z/', $quantity) === 1 ? Quantity::fromString($quantity)->toDecimal() : $quantity,
            'actual_market_price_uzs' => $body['actual_market_price_uzs'] ?? null,
            'fulfilled_product_id' => $named === null ? null : strtolower($named),
        ];
    }

    /**
     * The product bought: the one named, which must be the line's own or its
     * authorized replacement, or else the replacement when there is one.
     */
    private function boughtProduct(OrderItem $line, ?string $replacement, ?string $named): string
    {
        if ($named === null) {
            return $replacement ?? $line->product_id;
        }

        $named = strtolower($named);
        if ($named === $line->product_id || $named === $replacement) {
            return $named;
        }

        throw ValidationException::withMessages([
            'fulfilled_product_id' => 'The product bought is the line\'s own or its authorized replacement.',
        ]);
    }

    /**
     * The billable unit price, held to the bound of the product bought.
     */
    private function billablePrice(OrderItem $line, Order $order, bool $asReplacement, ?int $actual): int
    {
        if (! $asReplacement && $line->price_mode_snapshot === PriceMode::Fixed) {
            return $line->customer_unit_price_uzs_snapshot;
        }

        $billable = MoneyCalculator::increaseByPercent((int) $actual, Percentage::fromString($line->markup_percent_snapshot));
        $bound = $asReplacement ? PriceBound::replacement($line, $order) : (int) PriceBound::original($line, $order);

        if ($billable > $bound) {
            throw ApiException::conflict('customer_approval_required', [
                'approval_type' => 'price_over_tolerance',
                'ceiling_customer_unit_price_uzs' => $bound,
                'proposed_customer_unit_price_uzs' => $billable,
            ]);
        }

        return $billable;
    }
}
