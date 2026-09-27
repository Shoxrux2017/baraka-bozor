<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * The four order item states of `05` Section 10; `purchased` and `removed` are
 * terminal.
 */
enum OrderItemStatus: string
{
    case Pending = 'pending';
    case AwaitingCustomer = 'awaiting_customer';
    case Purchased = 'purchased';
    case Removed = 'removed';
}
