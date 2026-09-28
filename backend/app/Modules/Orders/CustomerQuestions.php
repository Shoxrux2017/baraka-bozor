<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\ApprovalType;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderItemStatus;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\User;

/**
 * A question the Shopper puts to the Customer about one line (`docs/04`
 * sections 14 to 20, `BR-APP-001` to `BR-APP-003`, `DL-54` (8)).
 *
 * The proposal is persisted as asked and never changes (`BR-APP-001`, held by
 * `customer_approvals_guard`). It reaches the Operator ten minutes after it
 * is asked and expires after thirty, from the server's clock. The line waits
 * for the Customer (`awaiting_customer`), and the Shopper goes on with the
 * others (`docs/04` section 21). One `approval_requested` history row names
 * the approval (`DL-54` (23)).
 */
final class CustomerQuestions
{
    /** Minutes after the question when it becomes the Operator's attention (`BR-APP-002`). */
    public const ATTENTION_AFTER_MINUTES = 10;

    /** Minutes after the question when it expires (`BR-APP-003`). */
    public const EXPIRES_AFTER_MINUTES = 30;

    /**
     * @param  array<string, mixed>  $proposal  the proposal's columns for its type
     */
    public static function ask(Order $order, OrderItem $line, User $shopper, ApprovalType $type, array $proposal, ?string $note): CustomerApproval
    {
        $now = now();

        $approval = new CustomerApproval;
        $approval->forceFill([
            'order_id' => $order->id,
            'order_item_id' => $line->id,
            'type' => $type,
            'status' => ApprovalStatus::Pending,
            'requested_by_user_id' => $shopper->id,
            ...$proposal,
            'request_note' => $note,
            'attention_at' => $now->copy()->addMinutes(self::ATTENTION_AFTER_MINUTES),
            'expires_at' => $now->copy()->addMinutes(self::EXPIRES_AFTER_MINUTES),
            'created_at' => $now,
            'updated_at' => $now,
        ])->save();

        $line->forceFill(['status' => OrderItemStatus::AwaitingCustomer])->save();

        $history = new OrderHistory;
        $history->forceFill([
            'order_id' => $order->id,
            'event_type' => OrderHistoryEvent::ApprovalRequested,
            'actor_type' => HistoryActorType::User,
            'actor_user_id' => $shopper->id,
            'details' => ['approval_id' => $approval->id, 'item_id' => $line->id, 'type' => $type->value],
        ])->save();

        return $approval;
    }
}
