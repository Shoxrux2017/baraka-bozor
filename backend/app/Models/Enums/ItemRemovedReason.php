<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * Why an order line was removed (`DL-3` S-9); `customer_removed` is an edit's
 * (`DL-37` (9)).
 */
enum ItemRemovedReason: string
{
    case Unavailable = 'unavailable';
    case CustomerRejected = 'customer_rejected';
    case ApprovalExpired = 'approval_expired';
    case CustomerRemoved = 'customer_removed';
    case OperatorRemoved = 'operator_removed';
    case OrderCancelled = 'order_cancelled';
}
