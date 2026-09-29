<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\CancellationReason;
use App\Models\Enums\CancellationRequestStatus;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\User;
use App\Support\Scope\ScopedLookup;
use Illuminate\Support\Facades\DB;

/**
 * `POST /operations/orders/{order}/cancel` with `delivery_failed` (`docs/09`
 * section 41, `docs/04` section 29, `BR-CAN-004`, `BR-CAN-005`, `DL-54` (12),
 * `DL-65`).
 *
 * Under the order lock: the order must be back in `ready_for_delivery` after
 * a failed delivery, else `409 order_state_conflict`; while the Customer's
 * cancellation request is pending, `409 cancellation_already_pending`, for
 * the Operator decides the request instead. The order is cancelled with
 * `delivery_failed` and the Operator's note, and one `status_changed` row
 * records it (`DL-54` (23)). It holds no current assignment and no open line
 * by then, and a cash order has nothing to refund.
 *
 * A cancelled order cancelled again is a natural repeat (`BR-CON-005`).
 * `unpaid_online` is Wave 5's.
 */
final class CancelFailedDelivery
{
    public function cancel(User $staff, string $orderId, ?string $note): Order
    {
        return DB::transaction(function () use ($staff, $orderId, $note): Order {
            $order = ScopedLookup::lockOrNotFound(Order::query()->whereKey($orderId));

            if ($order->status === OrderStatus::Cancelled) {
                return $order;
            }

            $failed = $order->courierAssignments()->where('ended_reason', AssignmentEndReason::DeliveryFailed->value)->exists();
            if ($order->status !== OrderStatus::ReadyForDelivery || ! $failed) {
                throw ApiException::conflict('order_state_conflict');
            }

            if ($order->cancellationRequests()->where('status', CancellationRequestStatus::Pending->value)->exists()) {
                throw ApiException::conflict('cancellation_already_pending');
            }

            $order->forceFill([
                'status' => OrderStatus::Cancelled,
                'cancelled_at' => now(),
                'cancellation_reason_code' => CancellationReason::DeliveryFailed,
            ])->save();

            $history = new OrderHistory;
            $history->forceFill([
                'order_id' => $order->id,
                'event_type' => OrderHistoryEvent::StatusChanged,
                'from_status' => OrderStatus::ReadyForDelivery,
                'to_status' => OrderStatus::Cancelled,
                'actor_type' => HistoryActorType::User,
                'actor_user_id' => $staff->id,
                'reason_code' => CancellationReason::DeliveryFailed,
                'note' => $note,
            ])->save();

            return $order;
        });
    }
}
