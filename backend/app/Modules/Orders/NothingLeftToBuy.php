<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\CancellationReason;
use App\Models\Enums\CancellationRequestStatus;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderCancellationRequest;

/**
 * An order whose every line is removed has nothing left to buy (`DL-54` (7)):
 * the action that removed the last line — the Shopper's unavailable line, the
 * Customer's rejection, the Operator's removal of an expired one — cancels it
 * in its own transaction, under the order lock it already holds, with
 * `no_items_purchased`. The Shopper's assignment ends with `order_cancelled`
 * and a pending cancellation request closes (`DL-54` (12)); no approval can be
 * pending, since an awaiting line is not removed.
 *
 * The action writes the one history row (`DL-54` (23)), carrying the move and
 * what this closed.
 */
final class NothingLeftToBuy
{
    /**
     * Cancels the order when every line is removed, and answers the move and
     * the request it closed; null when a line remains.
     *
     * @return array{from: OrderStatus, closed_cancellation_request_id: string|null}|null
     */
    public static function cancelIfSo(Order $order): ?array
    {
        if ($order->items()->where('status', '<>', OrderItemStatus::Removed->value)->exists()) {
            return null;
        }

        $now = now();
        $from = $order->status;

        $order->shopperAssignments()->whereNull('ended_at')->get()->each(
            static fn ($assignment) => $assignment->forceFill(['ended_at' => $now, 'ended_reason' => AssignmentEndReason::OrderCancelled])->save()
        );

        /** @var OrderCancellationRequest|null $request */
        $request = $order->cancellationRequests()->where('status', CancellationRequestStatus::Pending->value)->first();
        $request?->forceFill(['status' => CancellationRequestStatus::Closed, 'resolved_at' => $now])->save();

        $order->forceFill([
            'status' => OrderStatus::Cancelled,
            'cancelled_at' => $now,
            'cancellation_reason_code' => CancellationReason::NoItemsPurchased,
        ])->save();

        return ['from' => $from, 'closed_cancellation_request_id' => $request?->id];
    }
}
