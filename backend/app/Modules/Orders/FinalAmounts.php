<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\Enums\OrderItemStatus;
use App\Models\Order;
use App\Support\Money\MoneyCalculator;

/**
 * An order's final amounts (`BR-MONEY-004` to `BR-MONEY-006`, `docs/04`
 * section 22): the merchandise is the sum of the bought lines' stored totals,
 * each already rounded (`BR-MONEY-003`); the service fee is the snapshotted
 * rule applied to it; the total adds the delivery fee snapshot. Filled at
 * completion, and again when an Admin corrects a bought line's price after it
 * (`DL-54` (18)). The database holds the same sums
 * (`orders_final_amounts_check`, `orders_final_service_fee_check`).
 *
 * Called under the order lock, which every writer of a line takes first.
 */
final class FinalAmounts
{
    public static function fill(Order $order): void
    {
        $subtotal = 0;
        foreach ($order->items()->where('status', OrderItemStatus::Purchased->value)->get() as $line) {
            // A bought line always has its total (`order_items_purchased_check`).
            $subtotal = MoneyCalculator::sum($subtotal, (int) $line->line_total_uzs);
        }
        $fee = OrderTotals::serviceFeeOn($order, $subtotal);

        $order->forceFill([
            'final_merchandise_subtotal_uzs' => $subtotal,
            'final_service_fee_uzs' => $fee,
            'final_total_uzs' => MoneyCalculator::sum($subtotal, $fee, $order->delivery_fee_uzs_snapshot),
        ]);
    }
}
