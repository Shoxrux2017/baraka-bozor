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
use App\Models\OrderHistory;
use App\Models\OrderShopperAssignment;
use App\Models\User;
use App\Support\Scope\ScopedLookup;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * `POST|PUT /operations/orders/{order}/shopper-assignment` (`docs/09` section
 * 39, `docs/04` section 11, `BR-ASSIGN-001`, `BR-ASSIGN-002`,
 * `BR-ASSIGN-005`, `DL-37` (14)).
 *
 * Under the order lock, and then a shared lock on the Shopper's account so a
 * block cannot land between the check and the assignment (`DL-45` (2)):
 *
 * - an id that is not a Shopper's account is `422 validation_failed` on
 *   `shopper_id`, a blocked Shopper `409 staff_not_active`;
 * - the current Shopper again is a natural repeat (`BR-CON-005`);
 * - an assignment needs a `new` order; a reassignment a `shopping_assigned`
 *   one whose current assignment is the one the Operator replaces and has
 *   not started (`BR-ASSIGN-002`), so a stale or retried reassignment never
 *   undoes a newer one (`DL-45` (8)); anything else is
 *   `409 order_state_conflict`;
 * - a reassignment ends the current assignment with `reassigned`;
 * - the new assignment is a self-order when the Shopper's phone is the
 *   Customer's, and one history row, `shopper_assigned` with the move to
 *   `shopping_assigned` or `shopper_reassigned`, carries the assignment in
 *   its `details`.
 *
 * No push is sent in this wave (`DL-37` (15)).
 */
final class AssignShopper
{
    public function assign(User $staff, string $orderId, string $shopperId): Order
    {
        return $this->change($staff, $orderId, $shopperId, replaces: null);
    }

    public function reassign(User $staff, string $orderId, string $shopperId, string $replacesAssignmentId): Order
    {
        return $this->change($staff, $orderId, $shopperId, replaces: $replacesAssignmentId);
    }

    /**
     * @param  string|null  $replaces  the assignment a reassignment replaces;
     *                                 null for a first assignment
     */
    private function change(User $staff, string $orderId, string $shopperId, ?string $replaces): Order
    {
        return DB::transaction(function () use ($staff, $orderId, $shopperId, $replaces): Order {
            $order = ScopedLookup::lockOrNotFound(Order::query()->whereKey($orderId));
            $shopper = $this->lockShopper($shopperId);

            if ($shopper->status !== UserStatus::Active) {
                throw ApiException::conflict('staff_not_active');
            }

            $order->load('currentShopperAssignment');
            $current = $order->currentShopperAssignment;

            if ($current !== null && $current->shopper_id === $shopper->id) {
                return $order;
            }

            $allowed = $replaces === null
                ? $order->status === OrderStatus::New && $current === null
                : $order->status === OrderStatus::ShoppingAssigned
                    && $current !== null
                    && $current->id === $replaces
                    && $current->started_at === null;
            if (! $allowed) {
                throw ApiException::conflict('order_state_conflict');
            }

            $now = now();
            if ($current !== null) {
                $current->forceFill(['ended_at' => $now, 'ended_reason' => AssignmentEndReason::Reassigned])->save();
            }

            $assignment = new OrderShopperAssignment;
            $assignment->forceFill([
                'order_id' => $order->id,
                'shopper_id' => $shopper->id,
                'assigned_by_user_id' => $staff->id,
                'is_self_order' => $shopper->phone === $order->customer->phone,
                'assigned_at' => $now,
            ])->save();

            $from = $order->status;
            if ($from === OrderStatus::New) {
                $order->forceFill(['status' => OrderStatus::ShoppingAssigned])->save();
            }

            $details = [
                'assignment_id' => $assignment->id,
                'shopper_id' => $shopper->id,
                'is_self_order' => $assignment->is_self_order,
            ];
            if ($current !== null) {
                $details['previous_assignment_id'] = $current->id;
                $details['previous_shopper_id'] = $current->shopper_id;
            }

            $history = new OrderHistory;
            $history->forceFill([
                'order_id' => $order->id,
                'event_type' => $current === null ? OrderHistoryEvent::ShopperAssigned : OrderHistoryEvent::ShopperReassigned,
                'from_status' => $from === OrderStatus::New ? $from : null,
                'to_status' => $from === OrderStatus::New ? OrderStatus::ShoppingAssigned : null,
                'actor_type' => HistoryActorType::User,
                'actor_user_id' => $staff->id,
                'details' => $details,
            ])->save();

            return $order->unsetRelation('currentShopperAssignment');
        });
    }

    /**
     * The Shopper's account under a shared lock: a block waits for this
     * assignment to commit, and this assignment waits for a block in flight
     * and then sees it.
     */
    private function lockShopper(string $shopperId): User
    {
        $shopper = User::query()
            ->whereKey($shopperId)
            ->where('role', Role::Shopper->value)
            ->sharedLock()
            ->first();

        if ($shopper === null) {
            throw ValidationException::withMessages(['shopper_id' => 'The id is not a Shopper\'s account.']);
        }

        return $shopper;
    }
}
