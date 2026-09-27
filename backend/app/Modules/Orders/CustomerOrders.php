<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\Order;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;

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
}
