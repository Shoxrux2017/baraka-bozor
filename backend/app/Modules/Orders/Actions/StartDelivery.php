<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\CancellationRequestStatus;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\User;
use App\Modules\Orders\CourierOrders;
use Illuminate\Support\Facades\DB;

/**
 * `POST /courier/orders/{order}/start` (`docs/09` section 37, `docs/04`
 * section 27, `BR-ASSIGN-003`, `BR-DEL-001`, `BR-DEL-002`, `DL-54` (11),
 * (12), `DL-63`).
 *
 * Under the order lock, through the Courier's own current assignment read
 * after the lock (`DL-54` (3)):
 *
 * - a start needs the assignment accepted and the order `delivery_assigned`,
 *   else `409 delivery_state_conflict`;
 * - while the Customer's cancellation request is pending, the Courier does
 *   not set off: `409 delivery_state_conflict` with `details.reason`
 *   `cancellation_request_pending`, for an Operator decides the request
 *   (`BR-CAN-002`, `BR-CAN-003`). Filing a request takes the same lock;
 * - the order becomes `on_the_way` with `on_the_way_at`, and the assignment
 *   records `delivery_started_at` and `delay_at`, the threshold snapshotted
 *   on the order after it, past which the order needs the Operator's
 *   attention (`courier_delayed`);
 * - one `status_changed` row records the move (`DL-54` (23)).
 *
 * A started delivery started again is a natural repeat (`BR-CON-005`).
 */
final class StartDelivery
{
    public function start(User $courier, string $orderId): Order
    {
        return DB::transaction(function () use ($courier, $orderId): Order {
            [$order, $assignment] = CourierOrders::lockCurrent($courier, $orderId);

            if ($assignment->delivery_started_at !== null) {
                return $order;
            }

            if ($assignment->accepted_at === null || $order->status !== OrderStatus::DeliveryAssigned) {
                throw ApiException::conflict('delivery_state_conflict');
            }

            if ($order->cancellationRequests()->where('status', CancellationRequestStatus::Pending->value)->exists()) {
                throw ApiException::conflict('delivery_state_conflict', ['reason' => 'cancellation_request_pending']);
            }

            $now = now();
            $assignment->forceFill([
                'delivery_started_at' => $now,
                'delay_at' => $now->copy()->addMinutes($order->delivery_delay_threshold_minutes_snapshot),
            ])->save();
            $order->forceFill(['status' => OrderStatus::OnTheWay, 'on_the_way_at' => $now])->save();

            $history = new OrderHistory;
            $history->forceFill([
                'order_id' => $order->id,
                'event_type' => OrderHistoryEvent::StatusChanged,
                'from_status' => OrderStatus::DeliveryAssigned,
                'to_status' => OrderStatus::OnTheWay,
                'actor_type' => HistoryActorType::User,
                'actor_user_id' => $courier->id,
                'details' => ['assignment_id' => $assignment->id],
            ])->save();

            return $order;
        });
    }
}
