<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * Where a payment stands (`BR-PAY-004`): a cash payment exists only as
 * `paid`; an online obligation moves through the others (Wave 5).
 */
enum PaymentStatus: string
{
    case Unpaid = 'unpaid';
    case Pending = 'pending';
    case Paid = 'paid';
    case Cancelled = 'cancelled';
}
