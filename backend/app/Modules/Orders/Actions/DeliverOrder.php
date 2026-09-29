<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\PaymentMethod;
use App\Models\Enums\PaymentStatus;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\Payment;
use App\Models\User;
use App\Modules\Orders\CourierOrders;
use App\Support\Idempotency\IdempotencyStore;
use App\Support\Idempotency\RequestFingerprint;
use Illuminate\Validation\ValidationException;

/**
 * `POST /courier/orders/{order}/delivered` (`docs/09` section 37, `docs/04`
 * section 28, `BR-DEL-001`, `BR-DEL-004`, `BR-PAY-003`, `DL-54` (11), `DL-64`).
 *
 * Idempotent (`DL-39`). Under the order lock, through the Courier's own current
 * assignment read after the lock, on a delivery that set off
 * (`409 delivery_state_conflict` otherwise):
 *
 * - a cash order needs `cash_received_uzs` (`422` without it), equal to the
 *   final total, else `409 cash_amount_mismatch` with `details.expected_uzs`;
 * - one transaction writes the cash payment, `paid` and recorded by the
 *   Courier; the order `completed` with `completed_at`; the assignment
 *   `completed`; and one `payment_recorded` history row carrying the move
 *   (`DL-54` (23)).
 *
 * The online branch is Wave 5's: an online order cannot be on the way before
 * it (`DL-54` (1)), and one met here is refused rather than completed unpaid.
 *
 * A replay by the key, and a natural repeat with a new key — "deliver a
 * completed one from the same assignment" (`docs/09` section 49,
 * `BR-CON-005`) — answer the order through the assignment delivered ended,
 * while it is the order's latest Courier assignment (`DL-54` (3)), and write
 * nothing.
 */
final class DeliverOrder
{
    public const OPERATION = 'courier.delivered';

    public function __construct(private readonly IdempotencyStore $idempotency) {}

    public function deliver(User $courier, string $orderId, ?int $cashReceivedUzs, string $idempotencyKey): Order
    {
        return $this->idempotency->run(
            $courier->id,
            self::OPERATION,
            $idempotencyKey,
            RequestFingerprint::of(self::OPERATION, ['order' => $orderId], ['cash_received_uzs' => $cashReceivedUzs]),
            fn (): Order => $this->deliverNow($courier, $orderId, $cashReceivedUzs),
            static fn (string $id): Order => CourierOrders::endedBy($courier, $id, AssignmentEndReason::Completed),
        );
    }

    private function deliverNow(User $courier, string $orderId, ?int $cashReceivedUzs): Order
    {
        try {
            [$order, $assignment] = CourierOrders::lockCurrent($courier, $orderId);
        } catch (ApiException $refused) {
            if ($refused->status() !== 404) {
                throw $refused;
            }

            return CourierOrders::endedBy($courier, $orderId, AssignmentEndReason::Completed);
        }

        if ($order->status !== OrderStatus::OnTheWay || $assignment->delivery_started_at === null
            || $order->payment_method !== PaymentMethod::Cash || $order->final_total_uzs === null) {
            throw ApiException::conflict('delivery_state_conflict');
        }

        if ($cashReceivedUzs === null) {
            throw ValidationException::withMessages([
                'cash_received_uzs' => 'The cash received is required for a cash order.',
            ]);
        }
        if ($cashReceivedUzs !== $order->final_total_uzs) {
            throw ApiException::conflict('cash_amount_mismatch', ['expected_uzs' => $order->final_total_uzs]);
        }

        $now = now();
        $payment = new Payment;
        $payment->forceFill([
            'order_id' => $order->id,
            'method' => PaymentMethod::Cash,
            'amount_uzs' => $order->final_total_uzs,
            'status' => PaymentStatus::Paid,
            'paid_at' => $now,
            'recorded_by_user_id' => $courier->id,
        ])->save();

        $order->forceFill(['status' => OrderStatus::Completed, 'completed_at' => $now])->save();
        $assignment->forceFill([
            'completed_at' => $now,
            'ended_at' => $now,
            'ended_reason' => AssignmentEndReason::Completed,
        ])->save();

        $history = new OrderHistory;
        $history->forceFill([
            'order_id' => $order->id,
            'event_type' => OrderHistoryEvent::PaymentRecorded,
            'from_status' => OrderStatus::OnTheWay,
            'to_status' => OrderStatus::Completed,
            'actor_type' => HistoryActorType::User,
            'actor_user_id' => $courier->id,
            'details' => [
                'assignment_id' => $assignment->id,
                'payment_id' => $payment->id,
                'method' => PaymentMethod::Cash->value,
                'amount_uzs' => $payment->amount_uzs,
            ],
        ])->save();

        return $order;
    }
}
