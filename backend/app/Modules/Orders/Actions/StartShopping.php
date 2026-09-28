<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderShopperAssignment;
use App\Models\User;
use App\Modules\Orders\ShopperOrders;
use App\Support\Scope\ScopedLookup;
use Illuminate\Support\Facades\DB;

/**
 * `POST /shopper/orders/{order}/start` (`docs/09` section 29,
 * `docs/04` section 12, `BR-ASSIGN-003`).
 *
 * Under the order lock, through the Shopper's own current assignment
 * (`DL-54` (3)). A start needs the assignment accepted (`409
 * order_state_conflict` otherwise, `DL-56` (3)); it moves the order from
 * `shopping_assigned` to `shopping` with `shopping_started_at`, records the
 * start on the assignment, and writes one `status_changed` row (`DL-54`
 * (23)). From then on the Customer can no longer edit or cancel the order
 * directly (`BR-ORDER-004`, `BR-CAN-001`): the edit and the cancellation take
 * the same lock and read the start. A started shopping started again is a
 * natural repeat (`BR-CON-005`).
 */
final class StartShopping
{
    public function start(User $shopper, string $orderId): Order
    {
        return DB::transaction(function () use ($shopper, $orderId): Order {
            $order = ScopedLookup::lockOrNotFound(ShopperOrders::current($shopper)->whereKey($orderId));
            /** @var OrderShopperAssignment $assignment the scope guarantees it */
            $assignment = $order->currentShopperAssignment()->firstOrFail();

            if ($assignment->started_at !== null) {
                return $order;
            }

            if ($assignment->accepted_at === null || $order->status !== OrderStatus::ShoppingAssigned) {
                throw ApiException::conflict('order_state_conflict');
            }

            $now = now();
            $assignment->forceFill(['started_at' => $now])->save();
            $order->forceFill(['status' => OrderStatus::Shopping, 'shopping_started_at' => $now])->save();

            $history = new OrderHistory;
            $history->forceFill([
                'order_id' => $order->id,
                'event_type' => OrderHistoryEvent::StatusChanged,
                'from_status' => OrderStatus::ShoppingAssigned,
                'to_status' => OrderStatus::Shopping,
                'actor_type' => HistoryActorType::User,
                'actor_user_id' => $shopper->id,
                'details' => ['assignment_id' => $assignment->id],
            ])->save();

            return $order;
        });
    }
}
