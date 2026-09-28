<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Resources;

use App\Models\CustomerApproval;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderItem;
use App\Modules\Orders\ApprovalExpiry;
use App\Modules\Orders\PriceBound;
use App\Modules\Orders\QuantityPolicy;
use App\Modules\Orders\ShopperLine;
use App\Modules\Orders\ShopperOrders;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * An order as its Shopper sees it (`docs/09` section 28, `docs/02` section 11,
 * `DL-56` (1)).
 *
 * - The lines the Shopper sees (`ShopperOrders::sees()`), oldest first: what
 *   to buy and how much, the Customer's note and rule, the market and customer
 *   price snapshots, and the bound of each product the line may be bought
 *   with, as a customer price and as a market price (`DL-54` (5), (6)); the
 *   authorized replacement with its current market price; a purchase once
 *   made; a pending question to the Customer.
 * - The Customer's phone only while the order is `shopping`
 *   (interview 7.3); never the address, the name or any amount due.
 * - The Shopper's own assignment, and whether it may be accepted or started.
 *
 * Expects the caller's own assignment as `currentShopperAssignment` — in the
 * answer of a completion, the one it ended — with `items.fulfilledProduct` and
 * `items.approvals` loaded.
 *
 * @property-read Order $resource
 */
final class ShopperOrderResource extends JsonResource
{
    public function __construct(Order $order)
    {
        parent::__construct($order);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $order = $this->resource;
        $assignment = $order->currentShopperAssignment;
        $lines = $order->items
            ->filter(static fn (OrderItem $line): bool => ShopperOrders::sees($line))
            ->sortBy([['created_at', 'asc'], ['id', 'asc']])
            ->values();

        return [
            'id' => $order->id,
            'order_number' => $order->order_number,
            'status' => $order->status->value,
            'delivery_time_note' => $order->delivery_time_note,
            'customer_phone' => $order->status === OrderStatus::Shopping ? $order->recipient_phone_snapshot : null,
            'assignment' => ShopperOrderSummaryResource::assignment($assignment),
            'can_accept' => $assignment !== null && $assignment->accepted_at === null,
            'can_start' => $assignment !== null && $assignment->accepted_at !== null && $assignment->started_at === null
                && $order->status === OrderStatus::ShoppingAssigned,
            'items' => $lines->map(fn (OrderItem $line): array => $this->line($line, $order))->all(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function line(OrderItem $line, Order $order): array
    {
        $original = PriceBound::original($line, $order);
        $replaced = ShopperLine::replacementOf($line) !== null;
        $question = $line->approvals->first(static fn (CustomerApproval $approval): bool => ApprovalExpiry::isOpen($approval));

        return [
            'id' => $line->id,
            'product_id' => $line->product_id,
            'name_uz' => $line->product_name_uz_snapshot,
            'name_ru' => $line->product_name_ru_snapshot,
            'unit_code' => $line->unit_code_snapshot->value,
            'price_mode' => $line->price_mode_snapshot->value,
            'quantity' => QuantityPolicy::format($line->unit_code_snapshot, $line->ordered_quantity),
            'approved_quantity_cap' => $line->approved_quantity_cap === null
                ? null
                : QuantityPolicy::format($line->unit_code_snapshot, $line->approved_quantity_cap),
            'customer_note' => $line->customer_note_snapshot,
            'substitution_policy' => $line->substitution_policy_snapshot->value,
            'status' => $line->status->value,
            'market_price_uzs' => $line->market_price_uzs_snapshot,
            'customer_unit_price_uzs' => $line->customer_unit_price_uzs_snapshot,
            'bound' => $original === null ? null : self::bound($original, $line),
            'replacement' => $replaced ? [
                'product_id' => $line->fulfilled_product_id,
                'name_uz' => $line->fulfilled_product_name_uz_snapshot,
                'name_ru' => $line->fulfilled_product_name_ru_snapshot,
                'market_price_uzs' => $line->fulfilledProduct?->market_price_uzs,
                'substitution_resolution' => $line->substitution_resolution?->value,
                'bound' => self::bound(PriceBound::replacement($line, $order), $line),
            ] : null,
            'purchase' => $line->status === OrderItemStatus::Purchased ? [
                'product_id' => $line->fulfilled_product_id,
                'purchased_quantity' => QuantityPolicy::format($line->unit_code_snapshot, (string) $line->purchased_quantity),
                'billable_quantity' => QuantityPolicy::format($line->unit_code_snapshot, $line->billable_quantity),
                'actual_market_price_uzs' => $line->actual_market_price_uzs,
                'billable_unit_price_uzs' => $line->billable_unit_price_uzs,
                'line_total_uzs' => $line->line_total_uzs,
            ] : null,
            'removed_reason_code' => $line->removed_reason_code?->value,
            'pending_approval' => $question === null ? null : [
                'id' => $question->id,
                'type' => $question->type->value,
                'expires_at' => $question->expires_at->toIso8601ZuluString(),
            ],
        ];
    }

    /**
     * @return array{customer_unit_price_uzs: int, market_price_uzs: int}
     */
    private static function bound(int $customerPriceUzs, OrderItem $line): array
    {
        return [
            'customer_unit_price_uzs' => $customerPriceUzs,
            'market_price_uzs' => PriceBound::asMarketPrice($customerPriceUzs, $line),
        ];
    }
}
