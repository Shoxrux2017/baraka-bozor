<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Order;
use App\Models\OrderHistory;
use Illuminate\Support\Facades\DB;

/**
 * An approval nobody answered expires thirty minutes after it was asked
 * (`BR-APP-003`), and expiry is never consent (`BR-APP-004`). `DL-54` (8)
 * writes it in two places and reads it everywhere:
 *
 * - **before an action** on the order, in a transaction of its own under the
 *   order lock (`expireOverdueOf()`), so a refusal that follows — the
 *   Customer's own `approval_expired` among them — cannot roll it back;
 * - **by the scheduled command** for every other order (W3-6);
 * - **on a read**, which shows an overdue pending approval as expired before
 *   either has run (`shownStatus()`, `isOpen()`).
 *
 * Each expiry writes one `approval_expired` history row, by the system.
 */
final class ApprovalExpiry
{
    /**
     * Expires the order's overdue approvals; returns how many.
     */
    public static function expireOverdueOf(string $orderId): int
    {
        return DB::transaction(static function () use ($orderId): int {
            /** @var Order|null $order */
            $order = Order::query()->whereKey($orderId)->lockForUpdate()->first();
            if ($order === null) {
                return 0;
            }

            $overdue = $order->approvals()
                ->where('status', ApprovalStatus::Pending->value)
                ->where('expires_at', '<=', now())
                ->lockForUpdate()
                ->get();

            foreach ($overdue as $approval) {
                $approval->forceFill(['status' => ApprovalStatus::Expired])->save();

                $history = new OrderHistory;
                $history->forceFill([
                    'order_id' => $order->id,
                    'event_type' => OrderHistoryEvent::ApprovalExpired,
                    'actor_type' => HistoryActorType::System,
                    'details' => ['approval_id' => $approval->id, 'item_id' => $approval->order_item_id],
                ])->save();
            }

            return $overdue->count();
        });
    }

    /**
     * The status a read shows: a pending approval past its expiry is expired.
     */
    public static function shownStatus(CustomerApproval $approval): ApprovalStatus
    {
        return $approval->status === ApprovalStatus::Pending && ! $approval->expires_at->isFuture()
            ? ApprovalStatus::Expired
            : $approval->status;
    }

    /**
     * Whether the approval still waits for the Customer.
     */
    public static function isOpen(CustomerApproval $approval): bool
    {
        return self::shownStatus($approval) === ApprovalStatus::Pending;
    }
}
