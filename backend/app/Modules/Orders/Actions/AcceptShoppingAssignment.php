<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderShopperAssignment;
use App\Models\User;
use App\Modules\Orders\ShopperOrders;
use App\Support\Scope\ScopedLookup;
use Illuminate\Support\Facades\DB;

/**
 * `POST /shopper/orders/{order}/accept` (`docs/09` section 29,
 * `docs/04` section 12, `BR-ASSIGN-003`).
 *
 * Under the order lock, through the Shopper's own current assignment — any
 * other order, a replaced Shopper's included, is the scope-safe `404`
 * (`DL-54` (3)). Accepting records the instant on the assignment and one
 * `shopper_accepted` history row (`DL-54` (2), (23)); an accepted assignment
 * accepted again is a natural repeat with no second row (`BR-CON-005`). The
 * order's status does not move.
 */
final class AcceptShoppingAssignment
{
    public function accept(User $shopper, string $orderId): Order
    {
        return DB::transaction(function () use ($shopper, $orderId): Order {
            $order = ScopedLookup::lockOrNotFound(ShopperOrders::current($shopper)->whereKey($orderId));
            /** @var OrderShopperAssignment $assignment the scope guarantees it */
            $assignment = $order->currentShopperAssignment()->firstOrFail();

            if ($assignment->accepted_at !== null) {
                return $order;
            }

            $assignment->forceFill(['accepted_at' => now()])->save();

            $history = new OrderHistory;
            $history->forceFill([
                'order_id' => $order->id,
                'event_type' => OrderHistoryEvent::ShopperAccepted,
                'actor_type' => HistoryActorType::User,
                'actor_user_id' => $shopper->id,
                'details' => ['assignment_id' => $assignment->id],
            ])->save();

            return $order;
        });
    }
}
