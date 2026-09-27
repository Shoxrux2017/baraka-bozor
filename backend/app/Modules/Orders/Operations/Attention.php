<?php

declare(strict_types=1);

namespace App\Modules\Orders\Operations;

use App\Models\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderShopperAssignment;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Query\Builder as QueryBuilder;

/**
 * The Operator's attention list (`docs/09` section 38, `DL-37` (16)): the
 * items the wave can produce. In Wave 2 that is `self_order` — an open order
 * whose current Shopper assignment is flagged a self-order (`BR-ASSIGN-005`,
 * interview 6.4). The item leaves the list when the order is completed or
 * cancelled, or when the Shopper is replaced by one who is not the Customer.
 * Each other type arrives with the wave that creates its state.
 */
final class Attention
{
    public const SELF_ORDER = 'self_order';

    /** @var list<string> */
    public const TYPES = [self::SELF_ORDER];

    /**
     * Narrows orders to those with a current self-order assignment.
     *
     * @param  Builder<Order>  $orders
     * @return Builder<Order>
     */
    public static function selfOrders(Builder $orders): Builder
    {
        return $orders
            ->whereIn('orders.status', array_map(static fn (OrderStatus $status): string => $status->value, OrderBoard::OPEN))
            ->whereExists(static fn (QueryBuilder $assignment) => $assignment->selectRaw('1')
                ->from('order_shopper_assignments')
                ->whereColumn('order_shopper_assignments.order_id', 'orders.id')
                ->whereNull('order_shopper_assignments.ended_at')
                ->where('order_shopper_assignments.is_self_order', true));
    }

    /**
     * The items, oldest first — the one waiting longest on top.
     *
     * @return list<array{type: string, order_id: string, order_number: int, since: string, shopper: array{id: string, full_name: string|null}}>
     */
    public static function items(): array
    {
        $assignments = OrderShopperAssignment::query()
            ->with(['order', 'shopper'])
            ->whereNull('ended_at')
            ->where('is_self_order', true)
            ->whereHas('order', static fn (Builder $order) => $order->whereIn(
                'status',
                array_map(static fn (OrderStatus $status): string => $status->value, OrderBoard::OPEN)
            ))
            ->orderBy('assigned_at')
            ->orderBy('id')
            ->get();

        return $assignments->map(static fn (OrderShopperAssignment $assignment): array => [
            'type' => self::SELF_ORDER,
            'order_id' => $assignment->order_id,
            'order_number' => $assignment->order->order_number,
            'since' => $assignment->assigned_at->toIso8601ZuluString(),
            'shopper' => ['id' => $assignment->shopper->id, 'full_name' => $assignment->shopper->full_name],
        ])->values()->all();
    }
}
