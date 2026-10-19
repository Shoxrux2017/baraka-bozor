<?php

declare(strict_types=1);

namespace App\Modules\Accounts;

use App\Models\Enums\OrderStatus;
use App\Models\Order;
use App\Models\User;

/**
 * The orders that stop a Customer from deleting the account: any order that is
 * neither completed nor cancelled (`BR-ROLE-013`).
 */
final class UnfinishedOrders
{
    /**
     * The oldest unfinished order of the Customer, or null when there is none.
     */
    public static function oldest(User $customer): ?Order
    {
        return Order::query()
            ->where('customer_id', $customer->id)
            ->whereNotIn('status', [OrderStatus::Completed->value, OrderStatus::Cancelled->value])
            ->orderBy('created_at')
            ->orderBy('order_number')
            ->first();
    }
}
