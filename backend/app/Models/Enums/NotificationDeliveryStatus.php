<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * Where one push delivery stands (`08` Section 26).
 */
enum NotificationDeliveryStatus: string
{
    case Queued = 'queued';
    case Sent = 'sent';
    case Failed = 'failed';
    case Skipped = 'skipped';
}
