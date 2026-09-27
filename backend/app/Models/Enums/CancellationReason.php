<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * Why an order was cancelled (`DL-3` S-9), on the order and on its history row.
 */
enum CancellationReason: string
{
    case CustomerCancelled = 'customer_cancelled';
    case CancellationRequestApproved = 'cancellation_request_approved';
    case UnpaidOnline = 'unpaid_online';
    case NoItemsPurchased = 'no_items_purchased';
    case DeliveryFailed = 'delivery_failed';
    case System = 'system';
}
