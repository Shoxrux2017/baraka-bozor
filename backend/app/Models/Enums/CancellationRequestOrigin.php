<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * Who filed a cancellation request (`08` Section 20). Wave 3 files only the
 * Customer's.
 */
enum CancellationRequestOrigin: string
{
    case Customer = 'customer';
    case Staff = 'staff';
}
