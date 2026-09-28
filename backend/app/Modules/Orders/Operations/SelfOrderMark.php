<?php

declare(strict_types=1);

namespace App\Modules\Orders\Operations;

use App\Models\Order;
use Illuminate\Database\Eloquent\Builder;

/**
 * The self-order mark (`BR-ASSIGN-005`, interview 6.4, `DL-54` (14)): the
 * Owner's audit flag. An order is marked while a self-order assignment of
 * either kind is current, or when its assignee started work — a Shopper who
 * started shopping, a Courier who accepted the delivery — however it ended.
 * One replaced before its assignee started stops marking the order.
 */
final class SelfOrderMark
{
    /**
     * Adds what `of()` reads, counted in SQL, so a page does not load every
     * assignment.
     *
     * @param  Builder<Order>  $orders
     * @return Builder<Order>
     */
    public static function add(Builder $orders): Builder
    {
        return $orders->withExists([
            'shopperAssignments as marked_by_shopper' => static fn (Builder $assignments) => self::shoppers($assignments),
            'courierAssignments as marked_by_courier' => static fn (Builder $assignments) => self::couriers($assignments),
        ]);
    }

    /**
     * Whether an order read through `add()` is marked.
     */
    public static function of(Order $order): bool
    {
        return (bool) $order->getAttribute('marked_by_shopper') || (bool) $order->getAttribute('marked_by_courier');
    }

    /**
     * Narrows orders to the marked ones.
     *
     * @param  Builder<Order>  $orders
     * @return Builder<Order>
     */
    public static function narrow(Builder $orders): Builder
    {
        return $orders->where(static fn (Builder $marked) => $marked
            ->whereHas('shopperAssignments', static fn (Builder $assignments) => self::shoppers($assignments))
            ->orWhereHas('courierAssignments', static fn (Builder $assignments) => self::couriers($assignments)));
    }

    /**
     * The Shopper assignments that mark their order.
     *
     * @template TBuilder of Builder
     *
     * @param  TBuilder  $assignments
     * @return TBuilder
     */
    public static function shoppers(Builder $assignments): Builder
    {
        return self::marking($assignments, 'started_at');
    }

    /**
     * The Courier assignments that mark their order.
     *
     * @template TBuilder of Builder
     *
     * @param  TBuilder  $assignments
     * @return TBuilder
     */
    public static function couriers(Builder $assignments): Builder
    {
        return self::marking($assignments, 'accepted_at');
    }

    /**
     * @template TBuilder of Builder
     *
     * @param  TBuilder  $assignments
     * @param  string  $worked  the instant the assignee started work
     * @return TBuilder
     */
    private static function marking(Builder $assignments, string $worked): Builder
    {
        $assignments->where('is_self_order', true)
            ->where(static fn (Builder $marking) => $marking->whereNull('ended_at')->orWhereNotNull($worked));

        return $assignments;
    }
}
