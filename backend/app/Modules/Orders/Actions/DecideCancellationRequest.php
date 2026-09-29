<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\CancellationReason;
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
use App\Modules\Orders\ApprovalExpiry;
use App\Modules\Orders\OrderPermissions;
use App\Support\Scope\ScopedLookup;
use Carbon\CarbonInterface;
use Illuminate\Support\Facades\DB;

/**
 * `POST /operations/cancellation-requests/{request}/decision` (`docs/09`
 * section 40, `docs/04` section 25, `BR-CAN-002`, `BR-CAN-005`, `BR-CAN-006`,
 * `DL-54` (12), (23), `DL-65`).
 *
 * Under the order lock the request is read again:
 *
 * - the same decision on a decided request is a natural repeat; the other
 *   decision, or any on a `closed` one, is
 *   `409 cancellation_request_already_decided`;
 * - **approve** cancels the order with `cancellation_request_approved`: the
 *   questions overdue at that instant expire first (`DL-54` (8)), those still
 *   pending close `cancelled`, its open lines are removed with
 *   `order_cancelled`, its current Shopper or Courier assignment ends
 *   `order_cancelled`, lines already bought stay bought, and nothing is due;
 * - **reject** lets the order go on;
 * - either keeps the Operator's note, and one `cancellation_request_decided`
 *   row records it, with the move to `cancelled` on an approval and the
 *   questions it closed in its `details` (`DL-54` (23)).
 *
 * The order answers as the board shows it.
 */
final class DecideCancellationRequest
{
    public const APPROVE = 'approve';

    public const REJECT = 'reject';

    public function decide(User $staff, string $requestId, string $decision, ?string $note): Order
    {
        /** @var OrderCancellationRequest $found */
        $found = ScopedLookup::firstOrNotFound(OrderCancellationRequest::query()->whereKey($requestId));

        return DB::transaction(function () use ($staff, $found, $decision, $note): Order {
            $order = ScopedLookup::lockOrNotFound(Order::query()->whereKey($found->order_id));
            /** @var OrderCancellationRequest $request */
            $request = $found->fresh() ?? throw ApiException::notFound();

            if ($request->status !== CancellationRequestStatus::Pending) {
                $same = ($request->status === CancellationRequestStatus::Approved && $decision === self::APPROVE)
                    || ($request->status === CancellationRequestStatus::Rejected && $decision === self::REJECT);
                if ($same) {
                    return $order;
                }

                throw ApiException::conflict('cancellation_request_already_decided');
            }

            $now = now();
            $request->forceFill([
                'status' => $decision === self::APPROVE ? CancellationRequestStatus::Approved : CancellationRequestStatus::Rejected,
                'resolved_by_user_id' => $staff->id,
                'resolution_note' => $note,
                'resolved_at' => $now,
            ]);

            $details = ['request_id' => $request->id, 'decision' => $decision];
            $from = null;
            if ($decision === self::APPROVE) {
                if (! in_array($order->status, OrderPermissions::REQUEST_WINDOW, true)) {
                    throw ApiException::conflict('order_state_conflict');
                }
                $from = $order->status;
                // At the cancellation's own instant, under its lock: a question
                // that fell due while the decision waited expires, rather than
                // closing as cancelled (DL-65 (2)).
                ApprovalExpiry::expireOverdueOf($order->id, $now);
                $details['cancelled_approval_ids'] = self::cancel($order, $now);
            }
            $request->save();

            $history = new OrderHistory;
            $history->forceFill([
                'order_id' => $order->id,
                'event_type' => OrderHistoryEvent::CancellationRequestDecided,
                'from_status' => $from,
                'to_status' => $from === null ? null : OrderStatus::Cancelled,
                'actor_type' => HistoryActorType::User,
                'actor_user_id' => $staff->id,
                'reason_code' => $from === null ? null : CancellationReason::CancellationRequestApproved,
                'note' => $note,
                'details' => $details,
            ])->save();

            return $order;
        });
    }

    /**
     * Cancels the order under its lock, in the lock order of `docs/07` section
     * 16 — its questions, then its lines — and answers the questions it closed.
     *
     * @return list<string>
     */
    private static function cancel(Order $order, CarbonInterface $now): array
    {
        /** @var list<string> $questions */
        $questions = $order->approvals()->where('status', ApprovalStatus::Pending->value)->orderBy('id')->pluck('id')->all();
        if ($questions !== []) {
            $order->approvals()->whereKey($questions)->update([
                'status' => ApprovalStatus::Cancelled->value,
                'resolved_at' => $now,
                'updated_at' => $now,
            ]);
        }

        $order->items()
            ->whereIn('status', [OrderItemStatus::Pending->value, OrderItemStatus::AwaitingCustomer->value])
            ->update([
                'status' => OrderItemStatus::Removed->value,
                'removed_reason_code' => ItemRemovedReason::OrderCancelled->value,
                'removed_at' => $now,
                'billable_quantity' => '0',
                'line_total_uzs' => 0,
                'updated_at' => $now,
            ]);

        foreach ([$order->currentShopperAssignment()->first(), $order->currentCourierAssignment()->first()] as $assignment) {
            $assignment?->forceFill(['ended_at' => $now, 'ended_reason' => AssignmentEndReason::OrderCancelled])->save();
        }

        $order->forceFill([
            'status' => OrderStatus::Cancelled,
            'cancelled_at' => $now,
            'cancellation_reason_code' => CancellationReason::CancellationRequestApproved,
        ])->save();

        return $questions;
    }
}
