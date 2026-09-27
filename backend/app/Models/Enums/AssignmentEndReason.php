<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * Why an assignment ended (`DL-3` S-9); a Shopper's never ends with
 * `delivery_failed`.
 */
enum AssignmentEndReason: string
{
    case Completed = 'completed';
    case Reassigned = 'reassigned';
    case DeliveryFailed = 'delivery_failed';
    case OrderCancelled = 'order_cancelled';
}
