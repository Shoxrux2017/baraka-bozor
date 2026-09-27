<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\PriceMode;
use App\Models\Order;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Query\Builder as QueryBuilder;

/**
 * A Customer's own orders (`docs/09` section 20, `BR-HIST-001`): another
 * Customer's order is the scope-safe `404`, like one that does not exist.
 */
final class CustomerOrders
{
    /**
     * @return Builder<Order>
     */
    public static function own(User $customer): Builder
    {
        return Order::query()->where('customer_id', $customer->id);
    }

    /**
     * Adds, per order, the lines not removed as `item_count`, their amounts'
     * sum as `lines_subtotal_uzs` — each line's stored total, or its price
     * times the ordered quantity, half-up (`round()` on a non-negative
     * numeric, as `order_items_line_total_check`) — and `has_estimate_line`.
     *
     * @param  Builder<Order>  $orders
     * @return Builder<Order>
     */
    public static function withLineSums(Builder $orders): Builder
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
}
