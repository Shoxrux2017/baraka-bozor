<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\Enums\ApprovalStatus;
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
        return $orders->selectSub(static fn (QueryBuilder $approvals) => $approvals->from('customer_approvals')
            ->selectRaw('count(*)')
            ->whereColumn('customer_approvals.order_id', 'orders.id')
            ->where('customer_approvals.status', ApprovalStatus::Pending->value)
            ->where('customer_approvals.expires_at', '>', now()), 'pending_approval_count');
    }
}
