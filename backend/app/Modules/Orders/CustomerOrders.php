<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\OrderStatus;
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
     * Adds `pending_approval_count`: the questions still waiting for the
     * Customer, those past their expiry left out as a read leaves them
     * (`DL-54` (8)), counted in SQL so a page does not load them.
     *
     * @param  Builder<Order>  $orders
     * @return Builder<Order>
     */
    public static function withPendingApprovalCount(Builder $orders): Builder
    {
        return $orders->addSelect(['pending_approval_count' => static fn (QueryBuilder $approvals) => $approvals->from('customer_approvals')
            ->selectRaw('count(*)')
            ->whereColumn('customer_approvals.order_id', 'orders.id')
            ->where('customer_approvals.status', ApprovalStatus::Pending->value)
            ->where('customer_approvals.expires_at', '>', now())]);
    }

    /**
     * The `current` tab is every status but `completed` and `cancelled`, the
     * `past` tab those two; no state leaves the list whole (`DL-91` (1)).
     *
     * @param  Builder<Order>  $orders
     * @return Builder<Order>
     */
    public static function inState(Builder $orders, ?string $state): Builder
    {
        $past = [OrderStatus::Completed->value, OrderStatus::Cancelled->value];

        return match ($state) {
            'current' => $orders->whereNotIn('status', $past),
            'past' => $orders->whereIn('status', $past),
            default => $orders,
        };
    }

    /**
     * Adds `picture_storage_key`: the current picture of the earliest line
     * (by creation, then id) whose product has one, `null` when none has
     * (`DL-91` (1)).
     *
     * @param  Builder<Order>  $orders
     * @return Builder<Order>
     */
    public static function withPictureKey(Builder $orders): Builder
    {
        return $orders->addSelect(['picture_storage_key' => static fn (QueryBuilder $pictures) => $pictures->from('order_items')
            ->join('product_images', 'product_images.product_id', '=', 'order_items.product_id')
            ->select('product_images.storage_key')
            ->whereColumn('order_items.order_id', 'orders.id')
            ->orderBy('order_items.created_at')
            ->orderBy('order_items.id')
            ->limit(1)]);
    }
}
