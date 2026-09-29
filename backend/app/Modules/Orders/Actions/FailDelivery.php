<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\DeliveryFailureReason;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\User;
use App\Modules\Orders\CourierOrders;
use Illuminate\Support\Facades\DB;

/**
 * `POST /courier/orders/{order}/not-delivered` (`docs/09` section 37,
 * `docs/04` section 29, `BR-DEL-003`, `DL-54` (11), `DL-55` (13), `DL-64`).
 *
 * Under the order lock, through the Courier's own current assignment read
 * after the lock, on a delivery that set off (`409 delivery_state_conflict`
 * otherwise):
 *
 * - the assignment ends `delivery_failed` with the reason, and the note
 *   `other` requires;
 * - the order returns to `ready_for_delivery`, keeping its first
 *   `ready_for_delivery_at` and clearing `on_the_way_at`, which the next start
 *   sets again (`DL-55` (13));
 * - one `delivery_failed` history row carries the move, the reason in its
 *   `details` and the note (`DL-54` (23)).
 *
 * The order then waits on the Operator (`delivery_failed` attention), who
 * assigns a Courier again or cancels it.
 *
 * Not keyed: a repeat after the assignment ended answers the order through
 * it, while it is the order's latest Courier assignment (`DL-54` (3)), and
 * writes nothing — whatever its reason, since the failure is already recorded.
 */
final class FailDelivery
{
    public function fail(User $courier, string $orderId, DeliveryFailureReason $reason, ?string $note): Order
    {
        try {
            return DB::transaction(fn (): Order => $this->failNow($courier, $orderId, $reason, $note));
        } catch (ApiException $refused) {
            if ($refused->status() !== 404) {
                throw $refused;
            }

            return CourierOrders::endedBy($courier, $orderId, AssignmentEndReason::DeliveryFailed);
        }
    }

    private function failNow(User $courier, string $orderId, DeliveryFailureReason $reason, ?string $note): Order
    {
        [$order, $assignment] = CourierOrders::lockCurrent($courier, $orderId);

        if ($order->status !== OrderStatus::OnTheWay || $assignment->delivery_started_at === null) {
            throw ApiException::conflict('delivery_state_conflict');
        }

        $assignment->forceFill([
            'ended_at' => now(),
            'ended_reason' => AssignmentEndReason::DeliveryFailed,
            'failed_reason_code' => $reason,
            'failed_note' => $note,
        ])->save();
        $order->forceFill(['status' => OrderStatus::ReadyForDelivery, 'on_the_way_at' => null])->save();

        $history = new OrderHistory;
        $history->forceFill([
            'order_id' => $order->id,
            'event_type' => OrderHistoryEvent::DeliveryFailed,
            'from_status' => OrderStatus::OnTheWay,
            'to_status' => OrderStatus::ReadyForDelivery,
            'actor_type' => HistoryActorType::User,
            'actor_user_id' => $courier->id,
            'note' => $note,
            'details' => ['assignment_id' => $assignment->id, 'reason_code' => $reason->value],
        ])->save();

        return $order;
    }
}
