<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\CustomerApproval;
use App\Models\Enums\OrderItemStatus;
use App\Models\OrderItem;
use App\Modules\Orders\Actions\DecideApproval;

/**
 * What a Customer's yes does to a line and what an earlier yes already put in
 * force, as the order says it (`DL-130` (2), (3)). `DecideApproval::applied`
 * stays the one source of what a yes writes.
 */
final class ApprovalTerms
{
    /**
     * The line's estimate after a yes and the signed change of each answer.
     * The yes is applied to a copy that is never saved.
     *
     * @return array{estimate_if_approved_uzs: int, change_if_approved_uzs: int, change_if_rejected_uzs: int}
     */
    public static function effectsOf(CustomerApproval $question, OrderItem $item): array
    {
        $now = OrderTotals::lineEstimate($item);
        $approved = clone $item;
        $approved->forceFill(['status' => OrderItemStatus::Pending, ...DecideApproval::applied($question)]);
        $estimate = OrderTotals::lineEstimate($approved);

        return [
            'estimate_if_approved_uzs' => $estimate,
            'change_if_approved_uzs' => $estimate - $now,
            'change_if_rejected_uzs' => -$now,
        ];
    }

    /**
     * The price and the quantity the Customer agreed to on a line still to
     * buy — `pending`, or `awaiting_customer` with a new question open — each
     * `null` when no yes set it; `null` when neither is set or the line is
     * bought or removed.
     *
     * @return array{customer_unit_price_uzs: int|null, quantity: string|null}|null
     */
    public static function agreedOf(OrderItem $item): ?array
    {
        if (! in_array($item->status, [OrderItemStatus::Pending, OrderItemStatus::AwaitingCustomer], true)) {
            return null;
        }

        $price = OrderTotals::agreedUnitPrice($item);
        $quantity = $item->approved_quantity_cap === null
            ? null
            : QuantityPolicy::format($item->unit_code_snapshot, $item->approved_quantity_cap);

        return $price === null && $quantity === null
            ? null
            : ['customer_unit_price_uzs' => $price, 'quantity' => $quantity];
    }
}
