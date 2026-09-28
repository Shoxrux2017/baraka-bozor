<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderItemStatus;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Query\Builder as QueryBuilder;

/**
 * The orders a Shopper reaches (`BR-ASSIGN-004`, `DL-54` (3)): those the
 * Shopper holds a current assignment on. Any other order — one whose
 * assignment was replaced or has ended included — stays outside the scope and
 * answers the scope-safe `404` (`ScopedLookup`).
 *
 * The lines a Shopper sees are every line but those the Customer took out
 * before shopping started (`customer_removed`): they were never the Shopper's
 * to buy.
 */
final class ShopperOrders
{
    /**
     * @return Builder<Order>
     */
    public static function current(User $shopper): Builder
    {
        return Order::query()->whereExists(static fn (QueryBuilder $assignment) => $assignment->selectRaw('1')
            ->from('order_shopper_assignments')
            ->whereColumn('order_shopper_assignments.order_id', 'orders.id')
            ->where('order_shopper_assignments.shopper_id', $shopper->id)
            ->whereNull('order_shopper_assignments.ended_at'));
    }

    /**
     * Adds `item_count` (the lines the Shopper sees) and `open_item_count`
     * (those still to buy or awaiting the Customer), counted in SQL so a page
     * does not load its lines.
     *
     * @param  Builder<Order>  $orders
     * @return Builder<Order>
     */
    public static function withLineCounts(Builder $orders): Builder
    {
        return $orders
            ->select('orders.*')
            ->selectSub(static fn (QueryBuilder $lines) => self::seen($lines)->selectRaw('count(*)'), 'item_count')
            ->selectSub(static fn (QueryBuilder $lines) => self::seen($lines)
                ->selectRaw('count(*)')
                ->whereIn('order_items.status', [OrderItemStatus::Pending->value, OrderItemStatus::AwaitingCustomer->value]), 'open_item_count');
    }

    /**
     * Whether the Shopper sees the line.
     */
    public static function sees(OrderItem $line): bool
    {
        return $line->removed_reason_code !== ItemRemovedReason::CustomerRemoved;
    }

    private static function seen(QueryBuilder $lines): QueryBuilder
    {
        return $lines->from('order_items')
            ->whereColumn('order_items.order_id', 'orders.id')
            ->where(static fn (QueryBuilder $line) => $line
                ->whereNull('order_items.removed_reason_code')
                ->orWhere('order_items.removed_reason_code', '<>', ItemRemovedReason::CustomerRemoved->value));
    }
}
