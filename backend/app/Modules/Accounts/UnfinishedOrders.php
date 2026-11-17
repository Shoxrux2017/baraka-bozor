<?php

declare(strict_types=1);

namespace App\Modules\Accounts;

use App\Models\Enums\OrderStatus;
use App\Models\Order;
use App\Models\User;
use App\Modules\Orders\OrderLineSums;

/**
 * The orders that stop a Customer from deleting the account: any order that is
 * neither completed nor cancelled (`BR-ROLE-013`). The `409` names the order
 * with its status and line count for the app's sheet (`DL-140`).
 */
final class UnfinishedOrders
{
    /**
     * The oldest unfinished order of the Customer, or null when there is none.
     */
    public static function oldest(User $customer): ?Order
    {
        return OrderLineSums::add(Order::query())
            ->where('customer_id', $customer->id)
            ->whereNotIn('status', [OrderStatus::Completed->value, OrderStatus::Cancelled->value])
            ->orderBy('created_at')
            ->orderBy('order_number')
            ->first();
    }

    /**
     * The details of the `account_has_unfinished_orders` conflict; the order
     * comes from `oldest`, which carries the line count.
     *
     * @return array{order_id: string, order_number: int, status: string, item_count: int}
     */
    public static function details(Order $order): array
    {
        return [
            'order_id' => $order->id,
            'order_number' => $order->order_number,
            'status' => $order->status->value,
            'item_count' => (int) $order->getAttribute('item_count'),
        ];
    }
}
