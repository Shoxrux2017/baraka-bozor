<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\User;
use App\Modules\Orders\CourierOrders;
use Illuminate\Support\Facades\DB;

/**
 * `POST /courier/orders/{order}/accept` (`docs/09` section 37, `docs/04`
 * section 27, `BR-ASSIGN-003`, `DL-63`).
 *
 * Under the order lock, through the Courier's own current assignment read
 * after the lock — any other order, a replaced Courier's included, is the
 * scope-safe `404` (`DL-54` (3)). Accepting records the instant on the
 * assignment and one `courier_accepted` history row (`DL-54` (23)); an
 * accepted assignment accepted again is a natural repeat with no second row
 * (`BR-CON-005`). The order's status does not move.
 */
final class AcceptDelivery
{
    public function accept(User $courier, string $orderId): Order
    {
        return DB::transaction(function () use ($courier, $orderId): Order {
            [$order, $assignment] = CourierOrders::lockCurrent($courier, $orderId);

            if ($assignment->accepted_at !== null) {
                return $order;
            }

            $assignment->forceFill(['accepted_at' => now()])->save();

            $history = new OrderHistory;
            $history->forceFill([
                'order_id' => $order->id,
                'event_type' => OrderHistoryEvent::CourierAccepted,
                'actor_type' => HistoryActorType::User,
                'actor_user_id' => $courier->id,
                'details' => ['assignment_id' => $assignment->id],
            ])->save();

            return $order;
        });
    }
}
