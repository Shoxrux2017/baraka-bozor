<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\Enums\CancellationRequestStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Order;

/**
 * What the Customer may do with an order now, as the API tells the client
 * (`docs/09` section 20): edit it and cancel it directly while it is `new` or
 * `shopping_assigned` and the Shopper has not started (`BR-ORDER-004`,
 * `BR-CAN-001`); from `shopping` through `delivery_assigned`, file a
 * cancellation request when none is pending (`BR-CAN-002`, `DL-54` (12)).
 */
final class OrderPermissions
{
    /** The states a Customer files a cancellation request in (`BR-CAN-002`). */
    public const REQUEST_WINDOW = [
        OrderStatus::Shopping,
        OrderStatus::FinalPaymentPending,
        OrderStatus::ReadyForDelivery,
        OrderStatus::DeliveryAssigned,
    ];

    public static function canChange(Order $order): bool
    {
        if (! in_array($order->status, [OrderStatus::New, OrderStatus::ShoppingAssigned], true)) {
            return false;
        }

        return $order->currentShopperAssignment?->started_at === null;
    }

    /**
     * Expects `latestCancellationRequest` loaded.
     */
    public static function canRequestCancellation(Order $order): bool
    {
        return in_array($order->status, self::REQUEST_WINDOW, true)
            && $order->latestCancellationRequest?->status !== CancellationRequestStatus::Pending;
    }
}
