<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\CancellationReason;
use App\Models\Enums\CancellationRequestOrigin;
use App\Models\Enums\CancellationRequestStatus;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderCancellationRequest;
use App\Models\OrderHistory;
use App\Models\User;
use App\Modules\Orders\CustomerOrders;
use App\Modules\Orders\OrderPermissions;
use App\Support\Idempotency\IdempotencyStore;
use App\Support\Idempotency\RequestFingerprint;
use App\Support\Scope\ScopedLookup;
use Illuminate\Validation\ValidationException;

/**
 * `POST /customer/orders/{order}/cancel` (`docs/09` section 22, `docs/04`
 * sections 10 and 25, `BR-CAN-001`, `BR-CAN-002`, `BR-CAN-005`, `DL-37` (13),
 * `DL-54` (12), `DL-65`).
 *
 * While the order is `new` or `shopping_assigned` and the Shopper has not
 * started, the Customer cancels at once and owes nothing: the order becomes
 * `cancelled` with `customer_cancelled` and the optional reason, its open
 * lines `removed` with `order_cancelled`, the current Shopper assignment ends
 * with `order_cancelled`, and one history row records it. A cancelled order
 * is a natural repeat.
 *
 * From `shopping` through `delivery_assigned` the Customer files a request
 * instead, which an Operator decides: the reason is required (`422`), one
 * already pending is `409 cancellation_already_pending`, and one
 * `cancellation_requested` row records it. The order answers carrying it. From
 * `on_the_way` on, `409 order_cancellation_not_allowed` (`BR-CAN-003`).
 *
 * Idempotent (`DL-39`), both branches sharing the key: a retry with the same
 * key answers the order through the Customer's own orders. No push is sent
 * in this wave (`DL-37` (15)).
 */
final class CancelOrder
{
    public const OPERATION = 'orders.cancel';

    public function __construct(private readonly IdempotencyStore $idempotency) {}

    public function cancel(User $customer, string $orderId, ?string $reason, string $idempotencyKey): Order
    {
        return $this->idempotency->run(
            $customer->id,
            self::OPERATION,
            $idempotencyKey,
            RequestFingerprint::of(self::OPERATION, ['order' => $orderId], ['reason' => $reason]),
            fn (): Order => $this->cancelNow($customer, $orderId, $reason),
            static fn (string $id): Order => ScopedLookup::firstOrNotFound(CustomerOrders::own($customer)->whereKey($id)),
        );
    }

    private function cancelNow(User $customer, string $orderId, ?string $reason): Order
    {
        $order = ScopedLookup::lockOrNotFound(CustomerOrders::own($customer)->whereKey($orderId));
        $order->load('currentShopperAssignment');

        if ($order->status === OrderStatus::Cancelled) {
            return $order;
        }

        if (! OrderPermissions::canChange($order)) {
            return $this->request($customer, $order, $reason);
        }

        $from = $order->status;

        $order->items()
            ->whereIn('status', [OrderItemStatus::Pending->value, OrderItemStatus::AwaitingCustomer->value])
            ->update([
                'status' => OrderItemStatus::Removed->value,
                'removed_reason_code' => ItemRemovedReason::OrderCancelled->value,
                'removed_at' => now(),
                'billable_quantity' => '0',
                'line_total_uzs' => 0,
                'updated_at' => now(),
            ]);

        $assignment = $order->currentShopperAssignment;
        if ($assignment !== null) {
            $assignment->forceFill(['ended_at' => now(), 'ended_reason' => AssignmentEndReason::OrderCancelled])->save();
        }

        $order->forceFill([
            'status' => OrderStatus::Cancelled,
            'cancelled_at' => now(),
            'cancellation_reason_code' => CancellationReason::CustomerCancelled,
        ])->save();

        $history = new OrderHistory;
        $history->forceFill([
            'order_id' => $order->id,
            'event_type' => OrderHistoryEvent::StatusChanged,
            'from_status' => $from,
            'to_status' => OrderStatus::Cancelled,
            'actor_type' => HistoryActorType::User,
            'actor_user_id' => $customer->id,
            'reason_code' => CancellationReason::CustomerCancelled,
            'note' => $reason,
        ])->save();

        return $order;
    }

    private function request(User $customer, Order $order, ?string $reason): Order
    {
        if (! in_array($order->status, OrderPermissions::REQUEST_WINDOW, true)) {
            throw ApiException::conflict('order_cancellation_not_allowed');
        }

        if ($reason === null) {
            throw ValidationException::withMessages(['reason' => 'A cancellation request needs its reason.']);
        }

        if ($order->cancellationRequests()->where('status', CancellationRequestStatus::Pending->value)->exists()) {
            throw ApiException::conflict('cancellation_already_pending');
        }

        $request = new OrderCancellationRequest;
        $request->forceFill([
            'order_id' => $order->id,
            'origin' => CancellationRequestOrigin::Customer,
            'requested_by_user_id' => $customer->id,
            'status' => CancellationRequestStatus::Pending,
            'reason' => $reason,
        ])->save();

        $history = new OrderHistory;
        $history->forceFill([
            'order_id' => $order->id,
            'event_type' => OrderHistoryEvent::CancellationRequested,
            'actor_type' => HistoryActorType::User,
            'actor_user_id' => $customer->id,
            'note' => $reason,
            'details' => ['request_id' => $request->id],
        ])->save();

        return $order;
    }
}
