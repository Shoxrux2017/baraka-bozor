<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\Order;
use App\Models\OrderCourierAssignment;
use App\Models\OrderHistory;
use App\Models\User;
use App\Support\Scope\ScopedLookup;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * `POST|PUT /operations/orders/{order}/courier-assignment` (`docs/09` section
 * 39, `docs/04` section 26, `BR-ASSIGN-001`, `BR-ASSIGN-002`, `BR-ASSIGN-005`,
 * `DL-54` (10), `DL-62`), as the Shopper's assignment works (`AssignShopper`,
 * `DL-45`).
 *
 * Under the order lock, and then a shared lock on the Courier's account so a
 * block cannot land between the check and the assignment:
 *
 * - an id that is not a Courier's account is `422 validation_failed` on
 *   `courier_id`, a blocked Courier `409 staff_not_active`;
 * - the current Courier again is a natural repeat (`BR-CON-005`);
 * - an assignment needs a `ready_for_delivery` order without a current
 *   Courier — a first one, or one back after a failed delivery; a
 *   reassignment a `delivery_assigned` one whose current assignment is the
 *   one the Operator replaces and has not set off, so a stale or retried
 *   reassignment never undoes a newer one; anything else is
 *   `409 order_state_conflict`;
 * - a reassignment ends the current assignment with `reassigned`;
 * - the new assignment is a self-order when the Courier's phone is the
 *   Customer's, and one history row, `courier_assigned` with the move to
 *   `delivery_assigned` or `courier_reassigned`, carries the assignment in
 *   its `details`.
 *
 * No push is sent in this wave (`DL-37` (15)).
 */
final class AssignCourier
{
    public function assign(User $staff, string $orderId, string $courierId): Order
    {
        return $this->change($staff, $orderId, $courierId, replaces: null);
    }

    public function reassign(User $staff, string $orderId, string $courierId, string $replacesAssignmentId): Order
    {
        return $this->change($staff, $orderId, $courierId, replaces: $replacesAssignmentId);
    }

    /**
     * @param  string|null  $replaces  the assignment a reassignment replaces;
     *                                 null for a first assignment
     */
    private function change(User $staff, string $orderId, string $courierId, ?string $replaces): Order
    {
        return DB::transaction(function () use ($staff, $orderId, $courierId, $replaces): Order {
            $order = ScopedLookup::lockOrNotFound(Order::query()->whereKey($orderId));
            $courier = $this->lockCourier($courierId);

            if ($courier->status !== UserStatus::Active) {
                throw ApiException::conflict('staff_not_active');
            }

            $order->load('currentCourierAssignment');
            $current = $order->currentCourierAssignment;

            if ($current !== null && $current->courier_id === $courier->id) {
                return $order;
            }

            $allowed = $replaces === null
                ? $order->status === OrderStatus::ReadyForDelivery && $current === null
                : $order->status === OrderStatus::DeliveryAssigned
                    && $current !== null
                    && $current->id === $replaces
                    && $current->delivery_started_at === null;
            if (! $allowed) {
                throw ApiException::conflict('order_state_conflict');
            }

            $now = now();
            if ($current !== null) {
                $current->forceFill(['ended_at' => $now, 'ended_reason' => AssignmentEndReason::Reassigned])->save();
            }

            $assignment = new OrderCourierAssignment;
            $assignment->forceFill([
                'order_id' => $order->id,
                'courier_id' => $courier->id,
                'assigned_by_user_id' => $staff->id,
                'is_self_order' => $courier->phone === $order->customer->phone,
                'assigned_at' => $now,
            ])->save();

            $from = $order->status;
            if ($from === OrderStatus::ReadyForDelivery) {
                $order->forceFill(['status' => OrderStatus::DeliveryAssigned])->save();
            }

            $details = [
                'assignment_id' => $assignment->id,
                'courier_id' => $courier->id,
                'is_self_order' => $assignment->is_self_order,
            ];
            if ($current !== null) {
                $details['previous_assignment_id'] = $current->id;
                $details['previous_courier_id'] = $current->courier_id;
            }

            $history = new OrderHistory;
            $history->forceFill([
                'order_id' => $order->id,
                'event_type' => $current === null ? OrderHistoryEvent::CourierAssigned : OrderHistoryEvent::CourierReassigned,
                'from_status' => $from === OrderStatus::ReadyForDelivery ? $from : null,
                'to_status' => $from === OrderStatus::ReadyForDelivery ? OrderStatus::DeliveryAssigned : null,
                'actor_type' => HistoryActorType::User,
                'actor_user_id' => $staff->id,
                'details' => $details,
            ])->save();

            return $order->unsetRelation('currentCourierAssignment');
        });
    }

    /**
     * The Courier's account under a shared lock: a block waits for this
     * assignment to commit, and this assignment waits for a block in flight
     * and then sees it.
     */
    private function lockCourier(string $courierId): User
    {
        $courier = User::query()
            ->whereKey($courierId)
            ->where('role', Role::Courier->value)
            ->sharedLock()
            ->first();

        if ($courier === null) {
            throw ValidationException::withMessages(['courier_id' => 'The id is not a Courier\'s account.']);
        }

        return $courier;
    }
}
