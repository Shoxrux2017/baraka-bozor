<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalResolution;
use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\ApprovalType;
use App\Models\Enums\CancellationReason;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\SubstitutionResolution;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\User;
use App\Modules\Orders\ApprovalExpiry;
use App\Modules\Orders\CustomerApprovals;
use App\Modules\Orders\CustomerOrders;
use App\Modules\Orders\NothingLeftToBuy;
use App\Support\Idempotency\IdempotencyStore;
use App\Support\Idempotency\RequestFingerprint;
use App\Support\Scope\ScopedLookup;

/**
 * `POST /customer/approvals/{approval}/decision` (`docs/09` section 23,
 * `BR-APP-004` to `BR-APP-010`, `DL-54` (8), `DL-59`).
 *
 * Only the Customer decides, only on their own pending approval, only on the
 * proposal as persisted (`BR-APP-005`). An overdue approval is expired first,
 * in a transaction of its own, and then refused with `409 approval_expired`,
 * which the refusal cannot roll back; a resolved one is
 * `409 approval_already_resolved`. Idempotent (`DL-39`).
 *
 * Under the order lock, the approval and then its line:
 *
 * - **Approve** writes the proposal onto the line — the ceiling of the
 *   original or the price of the replacement it names, the replacement with
 *   its price, or the quantity cap — and returns the line to `pending` for the
 *   Shopper to buy (`DL-3` S-7, `DL-54` (5)). Approving the original's price
 *   drops a replacement authorized on the line, as buying the original does,
 *   since the Shopper asked about the original (`DL-54` (4), `DL-59` (3)).
 * - **Reject** removes the line with `customer_rejected` (`BR-APP-006`); when
 *   that leaves nothing to buy the order is cancelled (`DL-54` (7)).
 *
 * One `approval_decided` history row records it, carrying the order's move
 * when the order was cancelled (`DL-54` (23)).
 */
final class DecideApproval
{
    public const OPERATION = 'customer.approval-decision';

    public function __construct(private readonly IdempotencyStore $idempotency) {}

    public function decide(User $customer, string $approvalId, string $decision, string $idempotencyKey): CustomerApproval
    {
        $approval = ScopedLookup::firstOrNotFound(CustomerApprovals::own($customer)->whereKey($approvalId));
        ApprovalExpiry::expireOverdueOf($approval->order_id);

        return $this->idempotency->run(
            $customer->id,
            self::OPERATION,
            $idempotencyKey,
            RequestFingerprint::of(self::OPERATION, ['approval' => $approvalId], ['decision' => $decision]),
            fn (): CustomerApproval => $this->decideNow($customer, $approval->order_id, $approvalId, $decision),
            static fn (string $id): CustomerApproval => ScopedLookup::firstOrNotFound(CustomerApprovals::own($customer)->whereKey($id)),
        );
    }

    private function decideNow(User $customer, string $orderId, string $approvalId, string $decision): CustomerApproval
    {
        $order = ScopedLookup::lockOrNotFound(CustomerOrders::own($customer)->whereKey($orderId));
        /** @var CustomerApproval $approval */
        $approval = $order->approvals()->whereKey($approvalId)->lockForUpdate()->firstOrFail();

        if (ApprovalExpiry::shownStatus($approval) === ApprovalStatus::Expired) {
            throw ApiException::conflict('approval_expired');
        }
        if ($approval->status !== ApprovalStatus::Pending) {
            throw ApiException::conflict('approval_already_resolved');
        }

        /** @var OrderItem $line */
        $line = $order->items()->whereKey($approval->order_item_id)->lockForUpdate()->firstOrFail();
        $approve = $decision === 'approve';
        $now = now();

        $approval->forceFill([
            'status' => $approve ? ApprovalStatus::Approved : ApprovalStatus::Rejected,
            'resolution' => $approve ? ApprovalResolution::Approved : ApprovalResolution::Rejected,
            'resolved_by_user_id' => $customer->id,
            'resolved_at' => $now,
        ])->save();

        $cancelled = null;
        if ($approve) {
            $line->forceFill(['status' => OrderItemStatus::Pending, ...self::applied($approval)])->save();
        } else {
            $line->forceFill([
                'status' => OrderItemStatus::Removed,
                'removed_reason_code' => ItemRemovedReason::CustomerRejected,
                'removed_at' => $now,
                'billable_quantity' => '0',
                'line_total_uzs' => 0,
            ])->save();
            $cancelled = NothingLeftToBuy::cancelIfSo($order);
        }

        $details = ['approval_id' => $approval->id, 'item_id' => $line->id, 'decision' => $decision];
        if ($cancelled !== null && $cancelled['closed_cancellation_request_id'] !== null) {
            $details['closed_cancellation_request_id'] = $cancelled['closed_cancellation_request_id'];
        }

        $history = new OrderHistory;
        $history->forceFill([
            'order_id' => $order->id,
            'event_type' => OrderHistoryEvent::ApprovalDecided,
            'from_status' => $cancelled['from'] ?? null,
            'to_status' => $cancelled === null ? null : OrderStatus::Cancelled,
            'actor_type' => HistoryActorType::User,
            'actor_user_id' => $customer->id,
            'reason_code' => $cancelled === null ? null : CancellationReason::NoItemsPurchased,
            'details' => $details,
        ])->save();

        return $approval;
    }

    /**
     * What an approved proposal writes onto its line (`DL-3` S-7, `DL-54` (5)).
     *
     * @return array<string, mixed>
     */
    private static function applied(CustomerApproval $approval): array
    {
        return match ($approval->type) {
            ApprovalType::PriceOverTolerance => $approval->replacement_product_id === null
                ? [
                    'approved_unit_price_ceiling_uzs' => $approval->proposed_customer_unit_price_uzs,
                    'fulfilled_product_id' => null,
                    'fulfilled_product_name_uz_snapshot' => null,
                    'fulfilled_product_name_ru_snapshot' => null,
                    'fulfilled_unit_code_snapshot' => null,
                    'substitution_resolution' => null,
                    'approved_replacement_price_uzs' => null,
                ]
                : ['approved_replacement_price_uzs' => $approval->proposed_customer_unit_price_uzs],
            ApprovalType::Substitution => [
                'fulfilled_product_id' => $approval->replacement_product_id,
                'fulfilled_product_name_uz_snapshot' => $approval->replacement_name_uz_snapshot,
                'fulfilled_product_name_ru_snapshot' => $approval->replacement_name_ru_snapshot,
                'fulfilled_unit_code_snapshot' => $approval->replacement_unit_code_snapshot,
                'substitution_resolution' => SubstitutionResolution::Approved,
                'approved_replacement_price_uzs' => $approval->proposed_customer_unit_price_uzs,
            ],
            ApprovalType::ReducedQuantity => ['approved_quantity_cap' => $approval->proposed_quantity],
        };
    }
}
