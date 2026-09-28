<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\CustomerApproval;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Query\Builder as QueryBuilder;

/**
 * The approvals a Customer reaches: those on the Customer's own orders
 * (`BR-APP-005`). Any other is the scope-safe `404` (`ScopedLookup`). The
 * decision locks the order through `CustomerOrders::own`, whose scope is the
 * order row's own column, and reads the approval again under that lock.
 */
final class CustomerApprovals
{
    /**
     * @return Builder<CustomerApproval>
     */
    public static function own(User $customer): Builder
    {
        return CustomerApproval::query()->whereExists(static fn (QueryBuilder $order) => $order->selectRaw('1')
            ->from('orders')
            ->whereColumn('orders.id', 'customer_approvals.order_id')
            ->where('orders.customer_id', $customer->id));
    }
}
