<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\PaymentMethod;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\User;
use App\Modules\Orders\FinalAmounts;
use App\Modules\Orders\ShopperLine;
use App\Modules\Orders\ShopperOrders;
use App\Support\Idempotency\IdempotencyStore;
use App\Support\Idempotency\RequestFingerprint;
use Illuminate\Database\Eloquent\Builder;

/**
 * `POST /shopper/orders/{order}/complete` (`docs/09` section 35, `docs/04`
 * section 22, `BR-ASSIGN-006`, `DL-61`).
 *
 * Idempotent (`DL-39`). The order's overdue questions are expired first
 * (`DL-60` (1)). Then, under the order lock, through the Shopper's own current
 * assignment, on an order being shopped (`409 shopping_not_active`):
 *
 * - every line is bought or removed and no question is pending, else
 *   `409 shopping_incomplete` naming the lines still open;
 * - the final amounts are stored (`FinalAmounts`);
 * - a cash order becomes `ready_for_delivery`, with `shopping_completed_at` and
 *   `ready_for_delivery_at`. The online branch is Wave 5's, and no online order
 *   exists before it (`DL-54` (1)); one met here is refused rather than sent
 *   out unpaid;
 * - the assignment ends `completed`, so the order leaves the Shopper's list;
 * - one `status_changed` row records the move with the amounts (`DL-54` (23)).
 *
 * An order with nothing bought never reaches completion: the action that
 * removed its last line cancelled it (`DL-54` (7)). One met here is refused
 * rather than billed its fees alone.
 *
 * A replay answers the order through the assignment completion ended, while
 * it is the order's latest Shopper assignment (`DL-54` (3)).
 */
final class CompleteShopping
{
    public const OPERATION = 'shopper.complete';

    public function __construct(private readonly IdempotencyStore $idempotency) {}

    public function complete(User $shopper, string $orderId, string $idempotencyKey): Order
    {
        ShopperLine::expireFirst($shopper, $orderId);

        return $this->idempotency->run(
            $shopper->id,
            self::OPERATION,
            $idempotencyKey,
            RequestFingerprint::of(self::OPERATION, ['order' => $orderId], []),
            fn (): Order => $this->completeNow($shopper, $orderId),
            static fn (string $id): Order => ShopperOrders::completedBy($shopper, $id),
        );
    }

    private function completeNow(User $shopper, string $orderId): Order
    {
        [$order, $assignment] = ShopperOrders::lockCurrent($shopper, $orderId);

        if ($order->status !== OrderStatus::Shopping || $assignment->started_at === null) {
            throw ApiException::conflict('shopping_not_active');
        }

        // Every writer of a line or a question takes the order lock first, so
        // what is read here holds until the commit.
        $open = $order->items()
            ->where(static fn (Builder $line) => $line
                ->whereIn('status', [OrderItemStatus::Pending->value, OrderItemStatus::AwaitingCustomer->value])
                ->orWhereHas('approvals', static fn (Builder $approval) => $approval->where('status', ApprovalStatus::Pending->value)))
            ->orderBy('created_at')
            ->orderBy('id')
            ->pluck('id');
        if ($open->isNotEmpty()) {
            throw ApiException::conflict('shopping_incomplete', ['item_ids' => $open->values()->all()]);
        }

        if ($order->payment_method !== PaymentMethod::Cash
            || ! $order->items()->where('status', OrderItemStatus::Purchased->value)->exists()) {
            throw ApiException::conflict('order_state_conflict');
        }

        $now = now();
        FinalAmounts::fill($order);
        $order->forceFill([
            'status' => OrderStatus::ReadyForDelivery,
            'shopping_completed_at' => $now,
            'ready_for_delivery_at' => $now,
        ])->save();
        $assignment->forceFill([
            'completed_at' => $now,
            'ended_at' => $now,
            'ended_reason' => AssignmentEndReason::Completed,
        ])->save();

        $history = new OrderHistory;
        $history->forceFill([
            'order_id' => $order->id,
            'event_type' => OrderHistoryEvent::StatusChanged,
            'from_status' => OrderStatus::Shopping,
            'to_status' => OrderStatus::ReadyForDelivery,
            'actor_type' => HistoryActorType::User,
            'actor_user_id' => $shopper->id,
            'details' => [
                'assignment_id' => $assignment->id,
                'final_merchandise_subtotal_uzs' => $order->final_merchandise_subtotal_uzs,
                'final_service_fee_uzs' => $order->final_service_fee_uzs,
                'final_total_uzs' => $order->final_total_uzs,
            ],
        ])->save();

        return $order;
    }
}
