<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Models\Enums\CancellationReason;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\User;
use App\Modules\Orders\NothingLeftToBuy;
use App\Modules\Orders\ShopperLine;
use Illuminate\Support\Facades\DB;

/**
 * `POST /shopper/orders/{order}/items/{item}/unavailable` (`docs/09`
 * section 31, `docs/04` section 17, `DL-57`).
 *
 * Under the order lock, on a `pending` line of an order being shopped by the
 * caller (`ShopperLine`): the line is removed with `unavailable`, whatever its
 * rule — a replacement is the Shopper's other choice, before this one. One
 * `item_unavailable` history row keeps the Shopper's note. When that leaves
 * nothing to buy, the order is cancelled in the same transaction and the row
 * carries the move (`DL-54` (7), (23)).
 *
 * It takes no key: a repeat meets the line removed, `409
 * item_already_resolved`, and the app reloads the order (`DL-54` (9)).
 */
final class MarkItemUnavailable
{
    public function markUnavailable(User $shopper, string $orderId, string $itemId, ?string $note): Order
    {
        return DB::transaction(function () use ($shopper, $orderId, $itemId, $note): Order {
            [$order, , $line] = ShopperLine::lockPending($shopper, $orderId, $itemId);

            $line->forceFill([
                'status' => OrderItemStatus::Removed,
                'removed_reason_code' => ItemRemovedReason::Unavailable,
                'removed_at' => now(),
                'billable_quantity' => '0',
                'line_total_uzs' => 0,
            ])->save();

            $cancelled = NothingLeftToBuy::cancelIfSo($order);

            $details = ['item_id' => $line->id];
            if ($cancelled !== null && $cancelled['closed_cancellation_request_id'] !== null) {
                $details['closed_cancellation_request_id'] = $cancelled['closed_cancellation_request_id'];
            }

            $history = new OrderHistory;
            $history->forceFill([
                'order_id' => $order->id,
                'event_type' => OrderHistoryEvent::ItemUnavailable,
                'from_status' => $cancelled['from'] ?? null,
                'to_status' => $cancelled === null ? null : OrderStatus::Cancelled,
                'actor_type' => HistoryActorType::User,
                'actor_user_id' => $shopper->id,
                'reason_code' => $cancelled === null ? null : CancellationReason::NoItemsPurchased,
                'note' => $note,
                'details' => $details,
            ])->save();

            return $order;
        });
    }
}
