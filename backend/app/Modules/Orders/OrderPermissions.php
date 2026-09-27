<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\Enums\OrderStatus;
use App\Models\Order;

/**
 * What the Customer may do with an order now, as the API tells the client
 * (`docs/09` section 20): edit it and cancel it directly while it is `new` or
 * `shopping_assigned` and the Shopper has not started (`BR-ORDER-004`,
 * `BR-CAN-001`). A cancellation request from `shopping` on arrives with
 * Wave 3 (`DL-37` (13)); until the endpoint takes one, the client is not
 * offered it.
 */
final class OrderPermissions
{
    public static function canChange(Order $order): bool
    {
        if (! in_array($order->status, [OrderStatus::New, OrderStatus::ShoppingAssigned], true)) {
            return false;
        }

        return $order->currentShopperAssignment?->started_at === null;
    }

    public static function canRequestCancellation(Order $order): bool
    {
        return false;
    }
}
