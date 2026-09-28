<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalResolution;
use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\CancellationReason;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\User;
use App\Modules\Orders\ApprovalExpiry;
use App\Modules\Orders\NothingLeftToBuy;
use App\Support\Scope\ScopedLookup;
use Illuminate\Support\Facades\DB;

/**
 * `POST /operations/approvals/{approval}/resolve-expired` (`docs/09`
 * section 40, `docs/04` section 20, `BR-APP-007`, `DL-55` (11), `DL-60`).
 *
 * An expired approval is resolved only by removing its line: the Operator
 * cannot approve for the Customer (`docs/02` section 7). The approval is
 * expired first, in a transaction of its own (`DL-54` (8)); then, under the
 * order lock, the approval and its line:
 *
 * - a question not yet expired is `409 approval_not_expired`; one the
 *   Customer or a cancellation resolved is `409 approval_already_resolved`;
 *   the same removal again is a natural repeat, answered without writing
 *   (`DL-55` (2));
 * - the order must still be shopped and the line still waiting
 *   (`409 order_state_conflict`): a cancelled order's expired questions ask
 *   nothing of anyone (`DL-55` (11));
 * - the line is removed with `approval_expired`, the approval resolved as
 *   `remove_item` by the Operator, and one `approval_resolved` row keeps the
 *   note; when nothing is left to buy the order is cancelled
 *   (`DL-54` (7), (23)).
 */
final class ResolveExpiredApproval
{
    public function resolve(User $staff, string $approvalId, ?string $note): Order
    {
        /** @var CustomerApproval $found */
        $found = ScopedLookup::firstOrNotFound(CustomerApproval::query()->whereKey($approvalId));
        $now = now();
        ApprovalExpiry::expireOverdueOf($found->order_id, $now);

        return DB::transaction(static function () use ($staff, $found, $approvalId, $note, $now): Order {
            /** @var Order $order */
            $order = Order::query()->whereKey($found->order_id)->lockForUpdate()->firstOrFail();
            /** @var CustomerApproval $approval */
            $approval = $order->approvals()->whereKey($approvalId)->lockForUpdate()->firstOrFail();

            if ($approval->status === ApprovalStatus::Expired && $approval->resolution === ApprovalResolution::RemoveItem) {
                return $order;
            }
            if ($approval->status === ApprovalStatus::Pending) {
                throw ApiException::conflict('approval_not_expired');
            }
            if ($approval->status !== ApprovalStatus::Expired) {
                throw ApiException::conflict('approval_already_resolved');
            }

            /** @var OrderItem $line */
            $line = $order->items()->whereKey($approval->order_item_id)->lockForUpdate()->firstOrFail();
            if ($order->status !== OrderStatus::Shopping || $line->status !== OrderItemStatus::AwaitingCustomer) {
                throw ApiException::conflict('order_state_conflict');
            }

            $approval->forceFill([
                'resolution' => ApprovalResolution::RemoveItem,
                'resolved_by_user_id' => $staff->id,
                'resolved_at' => $now,
            ])->save();

            $line->forceFill([
                'status' => OrderItemStatus::Removed,
                'removed_reason_code' => ItemRemovedReason::ApprovalExpired,
                'removed_at' => $now,
                'billable_quantity' => '0',
                'line_total_uzs' => 0,
            ])->save();

            $cancelled = NothingLeftToBuy::cancelIfSo($order);

            $details = ['approval_id' => $approval->id, 'item_id' => $line->id];
            if ($cancelled !== null && $cancelled['closed_cancellation_request_id'] !== null) {
                $details['closed_cancellation_request_id'] = $cancelled['closed_cancellation_request_id'];
            }

            $history = new OrderHistory;
            $history->forceFill([
                'order_id' => $order->id,
                'event_type' => OrderHistoryEvent::ApprovalResolved,
                'from_status' => $cancelled['from'] ?? null,
                'to_status' => $cancelled === null ? null : OrderStatus::Cancelled,
                'actor_type' => HistoryActorType::User,
                'actor_user_id' => $staff->id,
                'reason_code' => $cancelled === null ? null : CancellationReason::NoItemsPurchased,
                'note' => $note,
                'details' => $details,
            ])->save();

            return $order;
        });
    }
}
