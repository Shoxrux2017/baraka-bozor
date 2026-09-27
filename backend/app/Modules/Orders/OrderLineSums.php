<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\PriceMode;
use App\Models\Order;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Query\Builder as QueryBuilder;

/**
 * Per-order sums of the lines not removed, computed in SQL so a page of
 * orders does not load its lines (`DL-42` (5)): `item_count`,
 * `lines_subtotal_uzs` — each line's stored total, or its price times the
 * ordered quantity, half-up (`round()` on a non-negative numeric, as
 * `order_items_line_total_check`) — and `has_estimate_line`. `OrderTotals`
 * turns them into the order's totals.
 */
final class OrderLineSums
{
    /**
     * @param  Builder<Order>  $orders
     * @return Builder<Order>
     */
    public static function add(Builder $orders): Builder
    {
        $removed = OrderItemStatus::Removed->value;

        return $orders
            ->select('orders.*')
            ->selectSub(static fn (QueryBuilder $lines) => $lines->from('order_items')
                ->selectRaw('count(*)')
                ->whereColumn('order_items.order_id', 'orders.id')
                ->where('order_items.status', '<>', $removed), 'item_count')
            ->selectSub(static fn (QueryBuilder $lines) => $lines->from('order_items')
                ->selectRaw('coalesce(sum(coalesce(line_total_uzs, round(customer_unit_price_uzs_snapshot * ordered_quantity))), 0)')
                ->whereColumn('order_items.order_id', 'orders.id')
                ->where('order_items.status', '<>', $removed), 'lines_subtotal_uzs')
            ->selectSub(static fn (QueryBuilder $lines) => $lines->from('order_items')
                ->selectRaw('count(*) > 0')
                ->whereColumn('order_items.order_id', 'orders.id')
                ->where('order_items.status', '<>', $removed)
                ->where('order_items.price_mode_snapshot', PriceMode::Estimate->value), 'has_estimate_line');
    }

    public static function totals(Order $order): OrderTotals
    {
        return OrderTotals::fromLines(
            $order,
            (int) $order->getAttribute('lines_subtotal_uzs'),
            (bool) $order->getAttribute('has_estimate_line'),
        );
    }
}
