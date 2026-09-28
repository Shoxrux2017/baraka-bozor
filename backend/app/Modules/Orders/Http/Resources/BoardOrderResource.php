<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Resources;

use App\Models\CustomerApproval;
use App\Models\Enums\OrderItemStatus;
use App\Models\Order;
use App\Models\OrderCourierAssignment;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\OrderShopperAssignment;
use App\Modules\Orders\ApprovalExpiry;
use App\Modules\Orders\OrderTotals;
use App\Modules\Orders\QuantityPolicy;
use App\Modules\Orders\ShopperLine;
use Carbon\CarbonInterface;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * An order as the Operator and the Admin see it (`docs/09` section 38): the
 * Customer and the address, the delivery wish, every line with its snapshots
 * — the market price among them, since staff reconcile what the Shopper pays
 * — the totals, every Shopper and Courier assignment with its self-order
 * flag, the questions to the Customer, and the whole history with who did
 * what, and the payment once made. Refunds are empty until Wave 5.
 *
 * Expects `items`, `history.actor`, `shopperAssignments.shopper`,
 * `shopperAssignments.assignedBy`, `courierAssignments.courier`,
 * `courierAssignments.assignedBy`, `livePayment.recordedBy` and the approvals'
 * people loaded.
 *
 * @property-read Order $resource
 */
final class BoardOrderResource extends JsonResource
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
        $assignments = $order->shopperAssignments->sortBy([['assigned_at', 'asc'], ['id', 'asc']])->values();

        return [
            'id' => $order->id,
            'order_number' => $order->order_number,
            'status' => $order->status->value,
            'payment_method' => $order->payment_method->value,
            'delivery_time_note' => $order->delivery_time_note,
            'customer' => [
                'id' => $order->customer_id,
                'full_name' => $order->recipient_name_snapshot,
                'phone' => $order->recipient_phone_snapshot,
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
            'items' => $items->map(static fn (OrderItem $item): array => [
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
                'market_price_uzs' => $item->market_price_uzs_snapshot,
                'customer_unit_price_uzs' => $item->customer_unit_price_uzs_snapshot,
                'markup_percent' => $item->markup_percent_snapshot,
                'line_total_uzs' => $item->status === OrderItemStatus::Removed ? 0 : OrderTotals::lineEstimate($item),
                'removed_reason_code' => $item->removed_reason_code?->value,
                // The purchase, with the price paid, which staff judge the
                // Shopper by (DL-44 (5), DL-57 (4)).
                'purchased_quantity' => $item->purchased_quantity === null
                    ? null
                    : QuantityPolicy::format($item->unit_code_snapshot, $item->purchased_quantity),
                'billable_quantity' => in_array($item->status, [OrderItemStatus::Pending, OrderItemStatus::AwaitingCustomer], true)
                    ? null
                    : QuantityPolicy::format($item->unit_code_snapshot, $item->billable_quantity),
                'actual_market_price_uzs' => $item->actual_market_price_uzs,
                'billable_unit_price_uzs' => $item->billable_unit_price_uzs,
                'replacement' => ShopperLine::replacementOf($item) === null ? null : [
                    'product_id' => $item->fulfilled_product_id,
                    'name_uz' => $item->fulfilled_product_name_uz_snapshot,
                    'name_ru' => $item->fulfilled_product_name_ru_snapshot,
                    'substitution_resolution' => $item->substitution_resolution?->value,
                ],
            ])->all(),
            'totals' => [
                'merchandise_subtotal_uzs' => $totals->merchandiseSubtotalUzs,
                'service_fee_uzs' => $totals->serviceFeeUzs,
                'delivery_fee_uzs' => $totals->deliveryFeeUzs,
                'total_uzs' => $totals->totalUzs,
                'total_kind' => $totals->kind,
            ],
            'shopper_assignments' => $assignments->map(static fn (OrderShopperAssignment $assignment): array => [
                'id' => $assignment->id,
                'shopper' => [
                    'id' => $assignment->shopper->id,
                    'full_name' => $assignment->shopper->full_name,
                    'phone' => $assignment->shopper->phone,
                ],
                'assigned_by' => ['id' => $assignment->assignedBy->id, 'full_name' => $assignment->assignedBy->full_name],
                'is_self_order' => $assignment->is_self_order,
                'assigned_at' => self::instant($assignment->assigned_at),
                'accepted_at' => self::instant($assignment->accepted_at),
                'started_at' => self::instant($assignment->started_at),
                'completed_at' => self::instant($assignment->completed_at),
                'ended_at' => self::instant($assignment->ended_at),
                'ended_reason' => $assignment->ended_reason?->value,
            ])->all(),
            'courier_assignments' => $order->courierAssignments
                ->sortBy([['assigned_at', 'asc'], ['id', 'asc']])
                ->values()
                ->map(static fn (OrderCourierAssignment $assignment): array => [
                    'id' => $assignment->id,
                    'courier' => [
                        'id' => $assignment->courier->id,
                        'full_name' => $assignment->courier->full_name,
                        'phone' => $assignment->courier->phone,
                    ],
                    'assigned_by' => ['id' => $assignment->assignedBy->id, 'full_name' => $assignment->assignedBy->full_name],
                    'is_self_order' => $assignment->is_self_order,
                    'assigned_at' => self::instant($assignment->assigned_at),
                    'accepted_at' => self::instant($assignment->accepted_at),
                    'delivery_started_at' => self::instant($assignment->delivery_started_at),
                    'delay_at' => self::instant($assignment->delay_at),
                    'completed_at' => self::instant($assignment->completed_at),
                    'ended_at' => self::instant($assignment->ended_at),
                    'ended_reason' => $assignment->ended_reason?->value,
                    'failed_reason_code' => $assignment->failed_reason_code?->value,
                    'failed_note' => $assignment->failed_note,
                ])
                ->all(),
            'approvals' => $order->approvals
                ->sortBy([['created_at', 'asc'], ['id', 'asc']])
                ->values()
                ->map(static fn (CustomerApproval $approval): array => self::approval($approval))
                ->all(),
            'payment' => $order->livePayment === null ? null : [
                'id' => $order->livePayment->id,
                'method' => $order->livePayment->method->value,
                'provider' => $order->livePayment->provider?->value,
                'status' => $order->livePayment->status->value,
                'amount_uzs' => $order->livePayment->amount_uzs,
                'paid_at' => self::instant($order->livePayment->paid_at),
                'recorded_by' => $order->livePayment->recordedBy === null ? null : [
                    'id' => $order->livePayment->recordedBy->id,
                    'full_name' => $order->livePayment->recordedBy->full_name,
                ],
            ],
            'refunds' => [],
            'history' => $order->history->sortBy([['created_at', 'asc'], ['id', 'asc']])->values()->map(
                static fn (OrderHistory $entry): array => [
                    'id' => $entry->id,
                    'event_type' => $entry->event_type->value,
                    'from_status' => $entry->from_status?->value,
                    'to_status' => $entry->to_status?->value,
                    'actor_type' => $entry->actor_type->value,
                    'actor' => $entry->actor === null ? null : [
                        'id' => $entry->actor->id,
                        'role' => $entry->actor->role->value,
                        'full_name' => $entry->actor->full_name,
                    ],
                    'reason_code' => $entry->reason_code?->value,
                    'note' => $entry->note,
                    'details' => $entry->details,
                    'created_at' => self::instant($entry->created_at),
                ]
            )->all(),
            'cancellation_reason_code' => $order->cancellation_reason_code?->value,
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

    private static function instant(?CarbonInterface $instant): ?string
    {
        return $instant?->toIso8601ZuluString();
    }

    /**
     * An approval as staff see it (`DL-58` (4)): the question, its proposal —
     * the price paid and the Customer's price, a quantity, a replacement — its
     * timers, who asked and who resolved it.
     *
     * @return array<string, mixed>
     */
    private static function approval(CustomerApproval $approval): array
    {
        return [
            'id' => $approval->id,
            'item_id' => $approval->order_item_id,
            'type' => $approval->type->value,
            'status' => ApprovalExpiry::shownStatus($approval)->value,
            'proposed_customer_unit_price_uzs' => $approval->proposed_customer_unit_price_uzs,
            'proposed_actual_market_price_uzs' => $approval->proposed_actual_market_price_uzs,
            'proposed_quantity' => $approval->proposed_quantity === null
                ? null
                : QuantityPolicy::format($approval->item->unit_code_snapshot, $approval->proposed_quantity),
            'replacement' => $approval->replacement_product_id === null ? null : [
                'product_id' => $approval->replacement_product_id,
                'name_uz' => $approval->replacement_name_uz_snapshot,
                'name_ru' => $approval->replacement_name_ru_snapshot,
            ],
            'request_note' => $approval->request_note,
            'requested_by' => ['id' => $approval->requestedBy->id, 'full_name' => $approval->requestedBy->full_name],
            'attention_at' => $approval->attention_at->toIso8601ZuluString(),
            'expires_at' => $approval->expires_at->toIso8601ZuluString(),
            'resolution' => $approval->resolution?->value,
            'resolved_by' => $approval->resolvedBy === null
                ? null
                : ['id' => $approval->resolvedBy->id, 'full_name' => $approval->resolvedBy->full_name],
            'resolved_at' => $approval->resolved_at?->toIso8601ZuluString(),
            'created_at' => $approval->created_at->toIso8601ZuluString(),
        ];
    }
}
