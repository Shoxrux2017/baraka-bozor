<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Resources;

use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalType;
use App\Models\Enums\OrderItemStatus;
use App\Models\Order;
use App\Models\OrderItem;
use App\Modules\Orders\ApprovalExpiry;
use App\Modules\Orders\OrderPermissions;
use App\Modules\Orders\OrderTotals;
use App\Modules\Orders\QuantityPolicy;
use App\Modules\Orders\ShopperLine;
use Carbon\CarbonInterface;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * An order as its Customer sees it (`docs/09` section 20): the snapshots it
 * was placed under — never a market price — its lines, its totals as
 * `DL-37` (10) defines them, the address it goes to, the delivery wish, what
 * the Customer may do with it now, its open questions (`DL-59` (2)), and its
 * instants. Payments and refunds arrive with their waves; until then the
 * payment is null and the list empty.
 *
 * Expects `items`, `currentShopperAssignment` and `approvals` loaded.
 *
 * @property-read Order $resource
 */
final class CustomerOrderResource extends JsonResource
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
        $items = $order->items->sortBy([['created_at', 'asc'], ['id', 'asc']])->values();
        $totals = OrderTotals::of($order, $items);
        $changeable = OrderPermissions::canChange($order);

        return [
            'id' => $order->id,
            'order_number' => $order->order_number,
            'status' => $order->status->value,
            'payment_method' => $order->payment_method->value,
            'delivery_time_note' => $order->delivery_time_note,
            'pending_approval_count' => $order->approvals->filter(static fn (CustomerApproval $approval): bool => ApprovalExpiry::isOpen($approval))->count(),
            'can_edit' => $changeable,
            'can_cancel_directly' => $changeable,
            'can_request_cancellation' => OrderPermissions::canRequestCancellation($order),
            'items' => $items->map(fn (OrderItem $item): array => $this->item($item, $order))->all(),
            'totals' => [
                'merchandise_subtotal_uzs' => $totals->merchandiseSubtotalUzs,
                'service_fee_uzs' => $totals->serviceFeeUzs,
                'delivery_fee_uzs' => $totals->deliveryFeeUzs,
                'total_uzs' => $totals->totalUzs,
                'total_kind' => $totals->kind,
            ],
            'address' => [
                'latitude' => $order->latitude_snapshot,
                'longitude' => $order->longitude_snapshot,
                'street' => $order->street_snapshot,
                'house' => $order->house_snapshot,
                'apartment' => $order->apartment_snapshot,
                'landmark' => $order->landmark_snapshot,
                'delivery_note' => $order->delivery_note_snapshot,
            ],
            'cancellation_reason_code' => $order->cancellation_reason_code?->value,
            'payment' => null,
            'refunds' => [],
            'timestamps' => [
                'created_at' => self::instant($order->created_at),
                'shopping_started_at' => self::instant($order->shopping_started_at),
                'shopping_completed_at' => self::instant($order->shopping_completed_at),
                'ready_for_delivery_at' => self::instant($order->ready_for_delivery_at),
                'on_the_way_at' => self::instant($order->on_the_way_at),
                'completed_at' => self::instant($order->completed_at),
                'cancelled_at' => self::instant($order->cancelled_at),
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function item(OrderItem $item, Order $order): array
    {
        $question = self::openQuestionOf($order, $item);

        $open = in_array($item->status, [OrderItemStatus::Pending, OrderItemStatus::AwaitingCustomer], true);

        return [
            'id' => $item->id,
            'product_id' => $item->product_id,
            'name_uz' => $item->product_name_uz_snapshot,
            'name_ru' => $item->product_name_ru_snapshot,
            'unit_code' => $item->unit_code_snapshot->value,
            'price_mode' => $item->price_mode_snapshot->value,
            'quantity' => QuantityPolicy::format($item->unit_code_snapshot, $item->ordered_quantity),
            'customer_note' => $item->customer_note_snapshot,
            'substitution_policy' => $item->substitution_policy_snapshot->value,
            'status' => $item->status->value,
            'customer_unit_price_uzs' => $item->customer_unit_price_uzs_snapshot,
            'line_total_uzs' => $item->status === OrderItemStatus::Removed ? 0 : OrderTotals::lineEstimate($item),
            'billable_quantity' => $open ? null : QuantityPolicy::format(
                $item->fulfilled_unit_code_snapshot ?? $item->unit_code_snapshot,
                $item->billable_quantity,
            ),
            'removed_reason_code' => $item->removed_reason_code?->value,
            // What the Customer pays for one unit once the line is bought — never
            // the price paid at the market (BR-PRICE-001, DL-57 (4)).
            'billable_unit_price_uzs' => $item->status === OrderItemStatus::Purchased ? $item->billable_unit_price_uzs : null,
            // While the line waits on a substitution question — open, or
            // expired until an Operator removes the line — the replacement is
            // the one asked about, not an earlier one no one will buy (DL-58 (3)).
            'replacement' => ShopperLine::replacementOf($item) === null || self::waitsOnASubstitution($order, $item) ? null : [
                'name_uz' => $item->fulfilled_product_name_uz_snapshot,
                'name_ru' => $item->fulfilled_product_name_ru_snapshot,
            ],
            'pending_approval' => $question === null ? null : [
                'id' => $question->id,
                'type' => $question->type->value,
                'proposed_customer_unit_price_uzs' => $question->proposed_customer_unit_price_uzs,
                'proposed_quantity' => $question->proposed_quantity === null
                    ? null
                    : QuantityPolicy::format($item->unit_code_snapshot, $question->proposed_quantity),
                'replacement' => $question->replacement_product_id === null ? null : [
                    'name_uz' => $question->replacement_name_uz_snapshot,
                    'name_ru' => $question->replacement_name_ru_snapshot,
                    'customer_unit_price_uzs' => $question->proposed_customer_unit_price_uzs,
                ],
                'request_note' => $question->request_note,
                'expires_at' => $question->expires_at->toIso8601ZuluString(),
            ],
        ];
    }

    /**
     * Whether the line waits on a substitution question.
     */
    private static function waitsOnASubstitution(Order $order, OrderItem $item): bool
    {
        if ($item->status !== OrderItemStatus::AwaitingCustomer) {
            return false;
        }

        $latest = $order->approvals
            ->filter(static fn (CustomerApproval $approval): bool => $approval->order_item_id === $item->id)
            ->sortBy([['created_at', 'desc'], ['id', 'desc']])
            ->first();

        return $latest?->type === ApprovalType::Substitution;
    }

    /**
     * The line's question still waiting for the Customer, if any.
     */
    private static function openQuestionOf(Order $order, OrderItem $item): ?CustomerApproval
    {
        return $order->approvals->first(
            static fn (CustomerApproval $approval): bool => $approval->order_item_id === $item->id && ApprovalExpiry::isOpen($approval)
        );
    }

    private static function instant(?CarbonInterface $instant): ?string
    {
        return $instant?->toIso8601ZuluString();
    }
}
