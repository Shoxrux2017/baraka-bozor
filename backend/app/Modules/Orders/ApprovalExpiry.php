<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Order;
use App\Models\OrderHistory;
use Carbon\CarbonInterface;
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
     * Expires the order's approvals overdue at the given instant (now by
     * default); returns how many. An action passes its own instant, so the
     * expiry and the action's own reading agree (`DL-59` (3)).
     */
    public static function expireOverdueOf(string $orderId, ?CarbonInterface $at = null): int
    {
        $at ??= now();

        return DB::transaction(static function () use ($orderId, $at): int {
            /** @var Order|null $order */
            $order = Order::query()->whereKey($orderId)->lockForUpdate()->first();
            if ($order === null) {
                return 0;
            }

            $overdue = $order->approvals()
                ->where('status', ApprovalStatus::Pending->value)
                ->where('expires_at', '<=', $at)
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
    public static function shownStatus(CustomerApproval $approval, ?CarbonInterface $at = null): ApprovalStatus
    {
        return $approval->status === ApprovalStatus::Pending && $approval->expires_at->lessThanOrEqualTo($at ?? now())
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
