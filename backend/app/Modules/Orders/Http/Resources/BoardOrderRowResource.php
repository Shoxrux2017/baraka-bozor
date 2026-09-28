<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Resources;

use App\Models\Order;
use App\Modules\Orders\OrderLineSums;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * An order as a row of the board (`docs/09` section 38): the number, when it
 * was placed, the Customer to call, the status, the payment method, the lines
 * and the total with its kind, and the current Shopper with the self-order
 * mark (`BR-ASSIGN-005`).
 *
 * Expects the sums of `OrderLineSums::add`, the `pending_approval_count` of
 * `CustomerOrders::withPendingApprovalCount` and `currentShopperAssignment.shopper`.
 *
 * @property-read Order $resource
 */
final class BoardOrderRowResource extends JsonResource
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
        $totals = OrderLineSums::totals($order);
        $assignment = $order->currentShopperAssignment;

        return [
            'id' => $order->id,
            'order_number' => $order->order_number,
            'created_at' => $order->created_at->toIso8601ZuluString(),
            'status' => $order->status->value,
            'payment_method' => $order->payment_method->value,
            'customer' => [
                'full_name' => $order->recipient_name_snapshot,
                'phone' => $order->recipient_phone_snapshot,
            ],
            'item_count' => (int) $order->getAttribute('item_count'),
            'pending_approval_count' => (int) $order->getAttribute('pending_approval_count'),
            'total_uzs' => $totals->totalUzs,
            'total_kind' => $totals->kind,
            'shopper' => $assignment === null ? null : [
                'id' => $assignment->shopper->id,
                'full_name' => $assignment->shopper->full_name,
            ],
            'is_self_order' => $assignment !== null && $assignment->is_self_order,
        ];
    }
}
