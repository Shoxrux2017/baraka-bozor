<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * Where an approval stands (`08` Section 18); `cancelled` ends one whose
 * order was cancelled before anyone decided it (`DL-54` (8)).
 */
enum ApprovalStatus: string
{
    case Pending = 'pending';
    case Approved = 'approved';
    case Rejected = 'rejected';
    case Expired = 'expired';
    case Cancelled = 'cancelled';
}
