<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * An idempotency key is `processing` under a lease until its operation
 * completes (`docs/07` Section 17).
 */
enum IdempotencyState: string
{
    case Processing = 'processing';
    case Completed = 'completed';
}
