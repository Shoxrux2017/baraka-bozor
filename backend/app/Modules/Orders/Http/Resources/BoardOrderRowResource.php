<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Resources;

use App\Models\Order;
use App\Modules\Orders\Operations\SelfOrderMark;
use App\Modules\Orders\OrderLineSums;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * An order as a row of the board (`docs/09` section 38): the number, when it
 * was placed, the Customer to call, the status, the payment method, the lines
 * and the total with its kind, the Shopper and the Courier the row names —
 * the current one, or else the one who completed the shopping or delivered —
 * and the self-order mark (`BR-ASSIGN-005`, `DL-54` (14)).
 *
 * Expects the sums of `OrderLineSums::add`, the `pending_approval_count` of
 * `CustomerOrders::withPendingApprovalCount`, the mark of `SelfOrderMark::add`,
 * and `namedShopperAssignment.shopper` and `namedCourierAssignment.courier`.
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
        $shopper = $order->namedShopperAssignment?->shopper;
        $courier = $order->namedCourierAssignment?->courier;

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
            'shopper' => $shopper === null ? null : ['id' => $shopper->id, 'full_name' => $shopper->full_name],
            'courier' => $courier === null ? null : ['id' => $courier->id, 'full_name' => $courier->full_name],
            'is_self_order' => SelfOrderMark::of($order),
        ];
    }
}
