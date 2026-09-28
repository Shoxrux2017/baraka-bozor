<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * Where a cancellation request stands (`08` Section 20); `closed` ends one
 * still pending when its order was cancelled another way (`DL-54` (12)).
 */
enum CancellationRequestStatus: string
{
    case Pending = 'pending';
    case Approved = 'approved';
    case Rejected = 'rejected';
    case Closed = 'closed';
}
