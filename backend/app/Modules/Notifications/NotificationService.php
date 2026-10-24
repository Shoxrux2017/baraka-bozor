<?php

declare(strict_types=1);

namespace App\Modules\Notifications;

use App\Models\Enums\NotificationType;
use App\Models\Order;
use App\Modules\Notifications\Jobs\SendNotification;

/**
 * The one door through which an action asks for a push. It queues the job
 * after the surrounding transaction commits, so an action that rolls back
 * tells nobody (`AGENTS.md` Section 6). It never touches the order.
 */
final class NotificationService
{
    /** A push queued longer ago than this is not sent (`DL-104` (10)). */
    public const int MAX_AGE_SECONDS = 3600;

    public function notify(
        NotificationType $type,
        string $recipientUserId,
        Order $order,
        ?string $actorUserId,
        ?string $approvalId = null,
    ): void {
        if ($recipientUserId === $actorUserId && $type !== NotificationType::OrderAccepted) {
            return;
        }

        $amountUzs = in_array($type, [NotificationType::ShoppingCompleted, NotificationType::PaymentRequired], true)
            ? $order->final_total_uzs
            : null;

        SendNotification::dispatch(
            $type->value,
            $recipientUserId,
            $order->id,
            $order->order_number,
            $amountUzs,
            $approvalId,
            now()->toIso8601String(),
        )->afterCommit();
    }

    /**
     * Tells the Customer, and the Shopper and the Courier who held the order,
     * that it is cancelled; whoever acted is left out.
     */
    public function notifyCancellation(
        Order $order,
        ?string $actorUserId,
        ?string $shopperUserId,
        ?string $courierUserId,
    ): void {
        $this->notify(NotificationType::OrderCancelled, $order->customer_id, $order, $actorUserId);

        if ($shopperUserId !== null) {
            $this->notify(NotificationType::ShoppingOrderCancelled, $shopperUserId, $order, $actorUserId);
        }

        if ($courierUserId !== null) {
            $this->notify(NotificationType::DeliveryCancelled, $courierUserId, $order, $actorUserId);
        }
    }
}
